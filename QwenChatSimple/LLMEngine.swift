import Foundation
import CoreML
import Accelerate

// シンプルなLLMエンジン実装
class LLMEngine: ObservableObject {
    static let shared = LLMEngine()
    
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var modelInfo = ModelInfo()
    
    private var modelPath: String?
    private var llamaWrapper = LlamaWrapper()
    
    struct ModelInfo {
        var name: String = "未読み込み"
        var size: String = "0 MB"
        var contextLength: Int = 2048
        var vocabSize: Int = 0
    }
    
    struct GenerationConfig {
        var maxTokens: Int = 256
        var temperature: Float = 0.7
        var topP: Float = 0.95
        var topK: Int = 40
        var repetitionPenalty: Float = 1.1
    }
    
    func loadModel(from path: String) async throws {
        await MainActor.run {
            self.isModelLoaded = false
        }
        
        // ファイルサイズ確認
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let sizeMB = Double(fileSize) / 1024 / 1024
        
        // 基本的なGGUFヘッダー読み取り（簡易版）
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw LLMError.fileNotFound
        }
        defer { fileHandle.closeFile() }
        
        // GGUFマジックナンバー確認
        let magicData = fileHandle.readData(ofLength: 4)
        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard magic == 0x46554747 || magic == 0x47475546 else { // "GGUF" in little/big endian
            throw LLMError.invalidFormat
        }
        
        // LlamaWrapperでモデルを読み込む
        try await llamaWrapper.loadModel(path: path)
        
        await MainActor.run {
            self.modelPath = path
            self.modelInfo = ModelInfo(
                name: URL(fileURLWithPath: path).lastPathComponent,
                size: String(format: "%.0f MB", sizeMB),
                contextLength: 2048,
                vocabSize: 32000 // Qwen default vocab size
            )
            self.isModelLoaded = true
        }
    }
    
    func generate(prompt: String, config: GenerationConfig = GenerationConfig()) async throws -> AsyncThrowingStream<String, Error> {
        guard isModelLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                await MainActor.run {
                    self.isGenerating = true
                }
                
                do {
                    // LlamaWrapperを使って生成
                    let response = try await llamaWrapper.generate(prompt: prompt, maxTokens: config.maxTokens)
                    
                    // レスポンスを文字単位でストリーミング
                    for char in response {
                        if !self.isGenerating {
                            break
                        }
                        
                        continuation.yield(String(char))
                        
                        // リアルな生成速度をシミュレート（10-20ms/char）
                        try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...20_000_000))
                    }
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                
                await MainActor.run {
                    self.isGenerating = false
                }
                
                continuation.finish()
            }
        }
    }
    
    func stopGeneration() {
        isGenerating = false
    }
    
    func getSystemInfo() -> String {
        return llamaWrapper.getSystemInfo()
    }
}

enum LLMError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case modelNotLoaded
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "モデルファイルが見つかりません"
        case .invalidFormat:
            return "無効なモデルフォーマットです"
        case .modelNotLoaded:
            return "モデルが読み込まれていません"
        case .generationFailed:
            return "生成に失敗しました"
        }
    }
}