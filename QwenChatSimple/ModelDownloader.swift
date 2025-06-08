import Foundation
import SwiftUI

class ModelDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var statusMessage = ""
    @Published var isModelAvailable = false
    
    private var downloadTask: URLSessionDownloadTask?
    private var downloadTasks: [URLSessionDownloadTask] = []
    
    init() {
        print("🔧 ModelDownloader初期化中...")
        checkModelAvailability()
        print("📁 ベースURL: \(Self.chunkDownloadConfig.baseURL)")
    }
    
    // Cloudflare R2 分割ファイル設定
    static let chunkDownloadConfig = ChunkDownloadConfig(
        baseURL: "https://pub-c75ca8dacc774c2f908a6bc2b8730696.r2.dev", // R2直接URL
        // 代替: "https://pub-YOUR_BUCKET_ID.r2.dev" // R2直接URL
        fileName: "qwen3-1.7b-q4_0.gguf",
        chunkPrefix: "qwen3-1.7b-q4_0.part",
        totalChunks: 7, // 1016.8MB ÷ 160MB = 7チャンク
        chunkSize: 160 * 1024 * 1024 // 160MB per chunk
    )
    
    // 推奨モデルリスト
    static let recommendedModels = [
        ModelInfo(
            name: "Qwen3-1.7B-Q4_0 (分割ダウンロード)",
            url: "", // チャンクダウンロードなのでURLは使わない
            size: "1.0 GB",
            description: "高性能、分割ダウンロードで安定",
            isChunked: true
        ),
        ModelInfo(
            name: "Qwen2.5-0.5B-Instruct",
            url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
            size: "394 MB",
            description: "最小モデル、高速動作",
            isChunked: false
        )
    ]
    
    struct ModelInfo: Identifiable {
        let id = UUID()
        let name: String
        let url: String
        let size: String
        let description: String
        let isChunked: Bool
    }
    
    struct ChunkDownloadConfig {
        let baseURL: String
        let fileName: String
        let chunkPrefix: String
        let totalChunks: Int
        let chunkSize: Int
    }
    
    func downloadModel(from urlString: String, to destinationURL: URL) async throws {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            statusMessage = "ダウンロード準備中..."
        }
        
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(self), delegateQueue: nil)
        
        do {
            let (tempURL, response) = try await session.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw DownloadError.serverError
            }
            
            // ファイルを移動
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            await MainActor.run {
                isDownloading = false
                statusMessage = "ダウンロード完了"
                isModelAvailable = true
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                statusMessage = "エラー: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // チャンク分割ダウンロード（レジューム対応）
    func downloadModelChunks() async throws {
        print("🚀 downloadModelChunks() 開始")
        let config = Self.chunkDownloadConfig
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let finalDestination = documentsPath.appendingPathComponent(config.fileName)
        
        print("📍 保存先: \(finalDestination.path)")
        print("🔗 ベースURL: \(config.baseURL)")
        print("📦 総チャンク数: \(config.totalChunks)")
        
        // 既にファイルが存在する場合はスキップ
        if FileManager.default.fileExists(atPath: finalDestination.path) {
            print("✅ モデルファイルは既に存在")
            await MainActor.run {
                isModelAvailable = true
                statusMessage = "モデルは既にインストール済みです"
            }
            return
        }
        
        print("🔄 ダウンロード開始...")
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            statusMessage = "チャンクダウンロード準備中..."
        }
        
        do {
            // チャンクの状態をチェック（レジューム対応）
            let chunkURLs = (1...config.totalChunks).map { chunkIndex in
                let url = URL(string: "\(config.baseURL)/\(config.chunkPrefix)\(String(format: "%02d", chunkIndex))")!
                print("🔗 チャンクURL[\(chunkIndex)]: \(url.absoluteString)")
                return url
            }
            
            // 既存チャンクを確認
            let existingChunks = checkExistingChunks()
            let completedChunks = existingChunks.count
            await MainActor.run {
                downloadProgress = Double(completedChunks) / Double(config.totalChunks)
                statusMessage = "既存チャンク確認: \(completedChunks)/\(config.totalChunks)"
            }
            
            print("📥 レジューム可能ダウンロード開始...")
            // レジューム対応ダウンロード実行
            let chunkData = try await downloadChunksWithResume(urls: chunkURLs, existingChunks: existingChunks)
            print("📦 ダウンロードされたチャンク数: \(chunkData.count)")
            
            await MainActor.run {
                statusMessage = "チャンクを結合中..."
            }
            
            // チャンクを結合
            let finalData = try combineChunks(chunkData)
            
            // 最終ファイルを保存
            try finalData.write(to: finalDestination)
            
            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
                statusMessage = "ダウンロード完了"
                isModelAvailable = true
            }
            
        } catch {
            await MainActor.run {
                isDownloading = false
                statusMessage = "エラー: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // 並列チャンクダウンロード
    private func downloadChunksInParallel(urls: [URL]) async throws -> [Int: Data] {
        let maxConcurrentDownloads = 3 // 同時ダウンロード数制限
        
        return try await withThrowingTaskGroup(of: (Int, Data).self, returning: [Int: Data].self) { group in
            var chunkData: [Int: Data] = [:]
            var nextIndex = 0
            var completedCount = 0
            
            // 初期タスクを追加
            for i in 0..<min(maxConcurrentDownloads, urls.count) {
                let currentIndex = i
                group.addTask {
                    let data = try await self.downloadSingleChunk(url: urls[currentIndex], chunkIndex: currentIndex + 1)
                    return (currentIndex, data)
                }
            }
            nextIndex = min(maxConcurrentDownloads, urls.count)
            
            // 結果を順次取得
            for try await (index, data) in group {
                chunkData[index] = data
                completedCount += 1
                let currentCompletedCount = completedCount
                
                await MainActor.run {
                    self.downloadProgress = Double(currentCompletedCount) / Double(urls.count)
                    self.statusMessage = "チャンク \(currentCompletedCount)/\(urls.count) ダウンロード完了"
                }
                
                // 残りのタスクを追加
                if nextIndex < urls.count {
                    let currentNextIndex = nextIndex
                    group.addTask {
                        let data = try await self.downloadSingleChunk(url: urls[currentNextIndex], chunkIndex: currentNextIndex + 1)
                        return (currentNextIndex, data)
                    }
                    nextIndex += 1
                }
            }
            
            return chunkData
        }
    }
    
    // 単一チャンクダウンロード
    private func downloadSingleChunk(url: URL, chunkIndex: Int) async throws -> Data {
        print("📥 チャンク\(chunkIndex)ダウンロード開始: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ チャンク\(chunkIndex): 無効なレスポンス")
                throw DownloadError.serverError
            }
            
            print("📊 チャンク\(chunkIndex): ステータス=\(httpResponse.statusCode), サイズ=\(data.count)バイト")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ チャンク\(chunkIndex): HTTPエラー \(httpResponse.statusCode)")
                throw DownloadError.serverError
            }
            
            print("✅ チャンク\(chunkIndex)ダウンロード完了")
            return data
        } catch {
            print("❌ チャンク\(chunkIndex)ダウンロードエラー: \(error)")
            throw error
        }
    }
    
    // チャンク結合
    private func combineChunks(_ chunkData: [Data]) throws -> Data {
        var finalData = Data()
        
        // 順番通りに結合
        for data in chunkData {
            finalData.append(data)
        }
        
        return finalData
    }
    
    // モデル可用性チェック
    func checkModelAvailability() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent(Self.chunkDownloadConfig.fileName)
        
        DispatchQueue.main.async {
            self.isModelAvailable = FileManager.default.fileExists(atPath: modelPath.path)
            if self.isModelAvailable {
                self.statusMessage = "モデルは利用可能です"
            } else {
                self.statusMessage = "モデルをダウンロードしてください"
            }
        }
    }
    
    // モデルファイルパス取得
    func getModelPath() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent(Self.chunkDownloadConfig.fileName)
        
        return FileManager.default.fileExists(atPath: modelPath.path) ? modelPath : nil
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        statusMessage = "ダウンロードをキャンセルしました"
    }
    
    private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        weak var downloader: ModelDownloader?
        
        init(_ downloader: ModelDownloader) {
            self.downloader = downloader
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            
            DispatchQueue.main.async {
                self.downloader?.downloadProgress = progress
                let mbDownloaded = Double(totalBytesWritten) / 1024 / 1024
                let mbTotal = Double(totalBytesExpectedToWrite) / 1024 / 1024
                self.downloader?.statusMessage = String(format: "%.0f MB / %.0f MB (%.0f%%)", mbDownloaded, mbTotal, progress * 100)
            }
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            // 完了処理はasync/awaitで行う
        }
    }
    
    // 既存チャンクのチェック
    private func checkExistingChunks() -> [Int: Data] {
        var existingChunks: [Int: Data] = [:]
        let config = Self.chunkDownloadConfig
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        for chunkIndex in 1...config.totalChunks {
            let chunkFileName = "\(config.chunkPrefix)\(String(format: "%02d", chunkIndex))"
            let chunkURL = documentsPath.appendingPathComponent(chunkFileName)
            
            if FileManager.default.fileExists(atPath: chunkURL.path) {
                do {
                    let chunkData = try Data(contentsOf: chunkURL)
                    existingChunks[chunkIndex - 1] = chunkData
                    print("✅ 既存チャンク\(chunkIndex)見つかりました (サイズ: \(chunkData.count)バイト)")
                } catch {
                    print("⚠️ 既存チャンク\(chunkIndex)の読み込みに失敗: \(error)")
                }
            }
        }
        
        print("📊 既存チャンク数: \(existingChunks.count)/\(config.totalChunks)")
        return existingChunks
    }
    
    // レジューム対応チャンクダウンロード
    private func downloadChunksWithResume(urls: [URL], existingChunks: [Int: Data]) async throws -> [Data] {
        let config = Self.chunkDownloadConfig
        var chunkData = Array(repeating: Data(), count: urls.count)
        
        // 既存チャンクを配列に設定
        for (index, data) in existingChunks {
            if index < chunkData.count {
                chunkData[index] = data
            }
        }
        
        // まだダウンロードされていないチャンクのみダウンロード
        let missingIndices = (0..<urls.count).filter { !existingChunks.keys.contains($0) }
        
        if missingIndices.isEmpty {
            print("✅ すべてのチャンクが既に存在します")
            return chunkData
        }
        
        print("📥 ダウンロードが必要なチャンク: \(missingIndices.map { $0 + 1 })")
        
        return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            let maxConcurrentDownloads = 3 // 同時ダウンロード数を制限
            var nextIndex = 0
            var completedCount = existingChunks.count
            
            // 最初のバッチをキューに追加
            for _ in 0..<min(maxConcurrentDownloads, missingIndices.count) {
                if nextIndex < missingIndices.count {
                    let missingIndex = missingIndices[nextIndex]
                    group.addTask {
                        let data = try await self.downloadSingleChunkWithRetry(url: urls[missingIndex], chunkIndex: missingIndex + 1)
                        return (missingIndex, data)
                    }
                    nextIndex += 1
                }
            }
            
            // 結果を処理
            for try await (index, data) in group {
                chunkData[index] = data
                
                // チャンクをディスクに保存（レジューム用）
                await saveChunkToDisk(data: data, chunkIndex: index + 1)
                
                completedCount += 1
                let currentCompletedCount = completedCount
                
                await MainActor.run {
                    self.downloadProgress = Double(currentCompletedCount) / Double(config.totalChunks)
                    self.statusMessage = "チャンク \(currentCompletedCount)/\(config.totalChunks) ダウンロード完了"
                }
                
                // 残りのタスクを追加
                if nextIndex < missingIndices.count {
                    let missingIndex = missingIndices[nextIndex]
                    group.addTask {
                        let data = try await self.downloadSingleChunkWithRetry(url: urls[missingIndex], chunkIndex: missingIndex + 1)
                        return (missingIndex, data)
                    }
                    nextIndex += 1
                }
            }
            
            return chunkData
        }
    }
    
    // リトライ機能付きチャンクダウンロード
    private func downloadSingleChunkWithRetry(url: URL, chunkIndex: Int, maxRetries: Int = 3) async throws -> Data {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("📥 チャンク\(chunkIndex)ダウンロード開始 (試行\(attempt)/\(maxRetries)): \(url.absoluteString)")
                
                // タイムアウト設定を追加
                var request = URLRequest(url: url)
                request.timeoutInterval = 60.0 // 60秒タイムアウト
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DownloadError.serverError
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw DownloadError.serverError
                }
                
                print("✅ チャンク\(chunkIndex)ダウンロード完了 (サイズ: \(data.count)バイト)")
                return data
                
            } catch {
                lastError = error
                print("❌ チャンク\(chunkIndex)ダウンロードエラー (試行\(attempt)/\(maxRetries)): \(error)")
                
                if attempt < maxRetries {
                    let delaySeconds = attempt * 2 // 指数バックオフ
                    print("⏳ \(delaySeconds)秒後に再試行...")
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? DownloadError.serverError
    }
    
    // チャンクをディスクに保存
    private func saveChunkToDisk(data: Data, chunkIndex: Int) async {
        let config = Self.chunkDownloadConfig
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let chunkFileName = "\(config.chunkPrefix)\(String(format: "%02d", chunkIndex))"
        let chunkURL = documentsPath.appendingPathComponent(chunkFileName)
        
        do {
            try data.write(to: chunkURL)
            print("💾 チャンク\(chunkIndex)をディスクに保存: \(chunkURL.path)")
        } catch {
            print("❌ チャンク\(chunkIndex)の保存に失敗: \(error)")
        }
    }
}

enum DownloadError: LocalizedError {
    case invalidURL
    case serverError
    case fileError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .serverError:
            return "サーバーエラーが発生しました"
        case .fileError:
            return "ファイル操作エラーが発生しました"
        }
    }
}