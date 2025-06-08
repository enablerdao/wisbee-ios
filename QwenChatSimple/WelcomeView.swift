import SwiftUI

struct WelcomeView: View {
    @ObservedObject var downloader: ModelDownloader
    @ObservedObject var llmEngine: LLMEngine
    @State private var currentStep: WelcomeStep = .welcome
    @State private var isAutoDownloadStarted = false
    @Environment(\.presentationMode) var presentationMode
    
    enum WelcomeStep {
        case welcome
        case downloading
        case completed
        case tutorial
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    switch currentStep {
                    case .welcome:
                        WelcomeStepView {
                            startAutoDownload()
                        }
                    case .downloading:
                        DownloadingStepView(downloader: downloader)
                    case .completed:
                        CompletedStepView {
                            loadModelAndContinue()
                        }
                    case .tutorial:
                        TutorialStepView {
                            finishWelcome()
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            checkAndStartAutoProcess()
        }
        .onChange(of: downloader.isModelAvailable) { isAvailable in
            if isAvailable && currentStep == .downloading {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentStep = .completed
                }
                // ダウンロード完了後、自動的にモデルロードを開始
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    loadModelAndContinue()
                }
            }
        }
    }
    
    private func checkAndStartAutoProcess() {
        if downloader.isModelAvailable {
            currentStep = .tutorial
        } else if !isAutoDownloadStarted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startAutoDownload()
            }
        }
    }
    
    private func startAutoDownload() {
        guard !isAutoDownloadStarted else { return }
        isAutoDownloadStarted = true
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentStep = .downloading
        }
        
        Task {
            do {
                try await downloader.downloadModelChunks()
                print("✅ 自動ダウンロード完了")
            } catch {
                print("❌ 自動ダウンロードエラー: \(error)")
            }
        }
    }
    
    private func loadModelAndContinue() {
        Task {
            do {
                try await llmEngine.loadModelFromDownloader(downloader)
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentStep = .tutorial
                }
            } catch {
                print("❌ モデル読み込みエラー: \(error)")
            }
        }
    }
    
    private func finishWelcome() {
        // ウェルカム画面を見たことを記録
        UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        // 画面を閉じる
        presentationMode.wrappedValue.dismiss()
    }
}

struct WelcomeStepView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // ロゴとタイトル
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Qwen3 Chat")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("AI チャットボット")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // 説明
            VStack(spacing: 12) {
                FeatureRow(icon: "cloud.fill", title: "クラウドから高速ダウンロード", description: "分割ダウンロードで安定取得")
                FeatureRow(icon: "iphone", title: "デバイス上でAI実行", description: "プライベートでセキュア")
                FeatureRow(icon: "bolt.fill", title: "リアルタイム会話", description: "スムーズなチャット体験")
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(16)
            
            // 開始ボタン
            Button(action: onStart) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Qwen3モデルをダウンロード")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Text("約1GB・自動で開始されます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DownloadingStepView: View {
    @ObservedObject var downloader: ModelDownloader
    
    var body: some View {
        VStack(spacing: 24) {
            // ダウンロード中アニメーション
            VStack(spacing: 16) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("AIモデルをダウンロード中...")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // プログレス表示
            VStack(spacing: 16) {
                // メインプログレスバー
                VStack(spacing: 8) {
                    HStack {
                        Text("進捗")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(downloader.downloadProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: downloader.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                }
                
                // 状態メッセージ
                Text(downloader.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // チャンク進捗ビジュアル
                VStack(spacing: 12) {
                    Text("ダウンロード状況")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { chunkIndex in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(chunkIndex <= Int(downloader.downloadProgress * 7) + 1 ? Color.green : Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Group {
                                            if chunkIndex <= Int(downloader.downloadProgress * 7) + 1 {
                                                Image(systemName: "checkmark")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            } else {
                                                Text("\(chunkIndex)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    )
                                
                                Text("Part\(chunkIndex)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(16)
            
            // エラー時のリトライボタン
            if downloader.statusMessage.contains("エラー") || downloader.statusMessage.contains("失敗") {
                Button(action: {
                    Task {
                        do {
                            try await downloader.downloadModelChunks()
                        } catch {
                            print("❌ リトライエラー: \(error)")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("リトライ")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.top)
            }
            
            // 豆知識
            TipCard(
                icon: "lightbulb.fill",
                title: "豆知識",
                description: "Qwen3は最新の多言語AI。日本語での自然な会話が得意です！"
            )
        }
    }
}

struct CompletedStepView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // 完了アニメーション
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("ダウンロード完了！")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("Qwen3モデルの準備ができました")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 統計情報
            VStack(spacing: 12) {
                StatRow(label: "モデルサイズ", value: "1.7B パラメータ")
                StatRow(label: "ファイルサイズ", value: "1.0 GB")
                StatRow(label: "量子化", value: "Q4_0")
                StatRow(label: "対応言語", value: "日本語・英語・中国語")
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(16)
            
            // 続行ボタン
            Button(action: onContinue) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("モデルを読み込んでチュートリアルへ")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
}

struct TutorialStepView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // タイトル
            VStack(spacing: 16) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("チュートリアル")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Qwen3 Chatの使い方を学びましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 使い方ガイド
            VStack(spacing: 16) {
                TutorialStep(number: "1", title: "質問を入力", description: "下部の入力欄に質問や会話を入力してください")
                TutorialStep(number: "2", title: "送信ボタンをタップ", description: "送信ボタンを押すとAIが応答を生成します")
                TutorialStep(number: "3", title: "会話を楽しむ", description: "AIと自然な日本語で会話ができます")
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(16)
            
            // サンプル質問
            VStack(spacing: 12) {
                Text("こんな質問をしてみてください：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(spacing: 8) {
                    SampleQuestion("今日の天気について教えて")
                    SampleQuestion("プログラミングについて質問したい")
                    SampleQuestion("日本の文化について話そう")
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(16)
            
            // チャット開始ボタン
            Button(action: onStart) {
                HStack {
                    Image(systemName: "message.fill")
                    Text("チャットを始める")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct TutorialStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
                .frame(width: 30, height: 30)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SampleQuestion: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack {
            Text("💬")
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(
            downloader: ModelDownloader(),
            llmEngine: LLMEngine.shared
        )
    }
}