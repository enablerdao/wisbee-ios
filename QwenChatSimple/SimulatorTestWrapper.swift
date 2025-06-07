import Foundation

// シミュレーター専用のテスト実装
class SimulatorTestWrapper {
    private var isLoaded = false
    private var modelMetadata: TestModelMetadata?
    
    struct TestModelMetadata {
        let name: String
        let size: String
        let vocabSize: Int
        let contextLength: Int
    }
    
    init() {
        print("🧪 Simulator Test Mode Initialized")
    }
    
    func loadModel(path: String) throws {
        print("🧪 [SIMULATOR] Loading test model from: \(URL(fileURLWithPath: path).lastPathComponent)")
        
        // ファイルの存在確認
        guard FileManager.default.fileExists(atPath: path) else {
            throw TestError.fileNotFound(path: path)
        }
        
        // ファイルサイズの取得
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let sizeMB = Double(fileSize) / 1024 / 1024
        
        // テストメタデータの設定
        self.modelMetadata = TestModelMetadata(
            name: URL(fileURLWithPath: path).lastPathComponent,
            size: String(format: "%.1f MB", sizeMB),
            vocabSize: 151936,
            contextLength: 2048
        )
        
        self.isLoaded = true
        
        print("✅ [SIMULATOR] Test model loaded successfully:")
        print("   📄 Name: \(modelMetadata!.name)")
        print("   📏 Size: \(modelMetadata!.size)")
        print("   🔤 Vocab: \(modelMetadata!.vocabSize) tokens")
        print("   📝 Context: \(modelMetadata!.contextLength) tokens")
    }
    
    func generate(prompt: String, maxTokens: Int = 100) async throws -> String {
        guard isLoaded, let metadata = modelMetadata else {
            throw TestError.modelNotLoaded
        }
        
        print("🧪 [SIMULATOR] Generating test response for: \"\(prompt)\"")
        
        // プロンプトの分析
        let analysis = analyzePrompt(prompt)
        print("🔍 [SIMULATOR] Prompt analysis: \(analysis.category)")
        
        // レスポンスの生成
        let response = generateTestResponse(for: analysis, maxTokens: maxTokens)
        
        // シミュレートされた処理時間
        let processingTime = Double.random(in: 0.5...2.0)
        try await Task.sleep(nanoseconds: UInt64(processingTime * 1_000_000_000))
        
        print("✅ [SIMULATOR] Response generated in \(String(format: "%.1f", processingTime))s")
        print("📝 [SIMULATOR] Response: \"\(response)\"")
        
        return response
    }
    
    private func analyzePrompt(_ prompt: String) -> PromptAnalysis {
        let lowercased = prompt.lowercased()
        
        if lowercased.contains("こんにちは") || lowercased.contains("hello") || lowercased.contains("hi") {
            return PromptAnalysis(category: "greeting", keywords: ["挨拶", "greeting"])
        }
        
        if lowercased.contains("天気") || lowercased.contains("weather") {
            return PromptAnalysis(category: "weather", keywords: ["天気", "weather"])
        }
        
        if lowercased.contains("iphone") || lowercased.contains("ios") || lowercased.contains("アプリ") {
            return PromptAnalysis(category: "technology", keywords: ["iPhone", "iOS", "技術"])
        }
        
        if lowercased.contains("ai") || lowercased.contains("人工知能") || lowercased.contains("機械学習") {
            return PromptAnalysis(category: "ai", keywords: ["AI", "人工知能"])
        }
        
        if lowercased.contains("料理") || lowercased.contains("レシピ") || lowercased.contains("cooking") {
            return PromptAnalysis(category: "cooking", keywords: ["料理", "レシピ"])
        }
        
        return PromptAnalysis(category: "general", keywords: ["一般的な質問"])
    }
    
    private func generateTestResponse(for analysis: PromptAnalysis, maxTokens: Int) -> String {
        let responseTemplates: [String: [String]] = [
            "greeting": [
                "こんにちは！私はQwen2.5アシスタントです。",
                "シミュレーターでテスト動作中です。",
                "何かお手伝いできることはありますか？"
            ],
            "weather": [
                "今日の天気についてお話しします。",
                "シミュレーターでは実際の天気データにアクセスできませんが、",
                "天気に関する一般的な情報をお答えできます。"
            ],
            "technology": [
                "iPhoneでのLLM実行について説明します。",
                "現在はシミュレーターで動作していますが、",
                "実機ではMetalを使用した高速推論が可能です。",
                "ローカル実行によりプライバシーが保護されます。"
            ],
            "ai": [
                "AI技術について説明させていただきます。",
                "私はQwen2.5-0.5Bモデルをベースとしています。",
                "現在はテストモードで簡易応答を生成しています。"
            ],
            "cooking": [
                "料理について質問をいただきありがとうございます。",
                "シミュレーターでは詳細なレシピ情報は制限されていますが、",
                "一般的な料理のアドバイスができます。"
            ],
            "general": [
                "ご質問ありがとうございます。",
                "現在シミュレーターのテストモードで動作中です。",
                "実機ではより詳細で自然な応答が可能です。",
                "何か他にご質問はありますか？"
            ]
        ]
        
        let templates = responseTemplates[analysis.category] ?? responseTemplates["general"]!
        let selectedTemplate = templates.prefix(min(maxTokens / 20, templates.count))
        
        return selectedTemplate.joined(separator: " ")
    }
    
    func getTestInfo() -> String {
        guard let metadata = modelMetadata else {
            return "モデルが読み込まれていません"
        }
        
        return """
        🧪 シミュレーターテストモード
        
        📊 モデル情報:
        • 名前: \(metadata.name)
        • サイズ: \(metadata.size)
        • 語彙数: \(metadata.vocabSize) トークン
        • コンテキスト長: \(metadata.contextLength) トークン
        
        ⚠️ 注意:
        • これはテスト実装です
        • 実機ではより高速で正確な推論が可能
        • Metal APIは実機でのみ完全動作
        
        🎯 テスト可能な質問例:
        • "こんにちは"
        • "今日の天気は？"
        • "iPhoneアプリについて"
        • "AIについて教えて"
        """
    }
    
    func unloadModel() {
        isLoaded = false
        modelMetadata = nil
        print("🧪 [SIMULATOR] Test model unloaded")
    }
}

struct PromptAnalysis {
    let category: String
    let keywords: [String]
}

enum TestError: Error, LocalizedError {
    case fileNotFound(path: String)
    case modelNotLoaded
    case simulatorLimitation
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "ファイルが見つかりません: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .modelNotLoaded:
            return "モデルが読み込まれていません"
        case .simulatorLimitation:
            return "シミュレーターでは制限があります"
        }
    }
}