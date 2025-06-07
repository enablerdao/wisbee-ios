//
//  LlamaWrapper.swift
//  QwenChatSimple
//

import Foundation
import Metal

// 実際の推論を行うラッパー（シミュレーター対応）
class LlamaWrapper {
    private let realWrapper = RealLlamaWrapper()
    private let simulatorWrapper = SimulatorTestWrapper()
    private var modelPath: String?
    private var isLoaded = false
    private let isSimulator: Bool
    
    init() {
        #if targetEnvironment(simulator)
        self.isSimulator = true
        print("🧪 Running in Simulator - Test Mode Enabled")
        #else
        self.isSimulator = false
        print("📱 Running on Device - Full Mode Enabled")
        #endif
    }
    
    func loadModel(path: String) async throws {
        do {
            if isSimulator {
                try simulatorWrapper.loadModel(path: path)
                print("🧪 [SIMULATOR] Test model loaded: \(URL(fileURLWithPath: path).lastPathComponent)")
            } else {
                try realWrapper.loadModel(path: path)
                print("📱 [DEVICE] Real model loaded: \(URL(fileURLWithPath: path).lastPathComponent)")
            }
            
            modelPath = path
            isLoaded = true
        } catch {
            print("❌ Failed to load model: \(error)")
            throw error
        }
    }
    
    func generate(prompt: String, maxTokens: Int = 100) async throws -> String {
        guard isLoaded else {
            throw NSError(domain: "LlamaWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        do {
            let response: String
            
            if isSimulator {
                print("🧪 [SIMULATOR] Generating test response for: \"\(prompt)\"")
                response = try await simulatorWrapper.generate(prompt: prompt, maxTokens: maxTokens)
            } else {
                print("📱 [DEVICE] Generating real response for: \"\(prompt)\"")
                response = try await realWrapper.generate(prompt: prompt, maxTokens: maxTokens)
            }
            
            print("✅ Response generated: \"\(response)\"")
            return response
        } catch {
            print("❌ Generation error: \(error)")
            
            // フォールバック応答
            let fallbackPrefix = isSimulator ? "[SIMULATOR ERROR]" : "[DEVICE ERROR]"
            return "\(fallbackPrefix) 申し訳ありません。応答の生成中にエラーが発生しました。\n\nエラー詳細: \(error.localizedDescription)"
        }
    }
    
    func getSystemInfo() -> String {
        if isSimulator {
            return simulatorWrapper.getTestInfo()
        } else {
            return """
            📱 実機モード
            
            ✅ 利用可能な機能:
            • Metal GPU加速
            • 完全なGGUF推論
            • 高速トークン生成
            • ストリーミング応答
            
            📊 モデル情報:
            • ファイル: \(modelPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "未読み込み")
            • 状態: \(isLoaded ? "読み込み済み" : "未読み込み")
            """
        }
    }
    
    func unloadModel() {
        if isSimulator {
            simulatorWrapper.unloadModel()
        }
        
        isLoaded = false
        modelPath = nil
        print("🗑️ Model unloaded")
    }
}