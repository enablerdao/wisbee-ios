import Foundation
import SwiftUI

class ModelDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var statusMessage = ""
    
    private var downloadTask: URLSessionDownloadTask?
    
    // 推奨モデルリスト
    static let recommendedModels = [
        ModelInfo(
            name: "Qwen2.5-0.5B-Instruct",
            url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
            size: "394 MB",
            description: "最小モデル、高速動作"
        ),
        ModelInfo(
            name: "Qwen2.5-1.5B-Instruct",
            url: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
            size: "1.0 GB",
            description: "バランス型、推奨"
        ),
        ModelInfo(
            name: "Qwen2.5-3B-Instruct",
            url: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
            size: "2.0 GB",
            description: "高性能、メモリ8GB以上推奨"
        )
    ]
    
    struct ModelInfo: Identifiable {
        let id = UUID()
        let name: String
        let url: String
        let size: String
        let description: String
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
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                statusMessage = "エラー: \(error.localizedDescription)"
            }
            throw error
        }
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