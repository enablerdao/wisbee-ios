import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var llmEngine = LLMEngine.shared
    @State private var inputText = ""
    @State private var messages: [Message] = [
        Message(content: "こんにちは！Qwen3-1.7Bチャットアプリへようこそ。", isUser: false)
    ]
    @State private var showFilePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var currentTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack {
                // モデル状態表示
                HStack {
                    Image(systemName: llmEngine.isModelLoaded ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundColor(llmEngine.isModelLoaded ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(llmEngine.isModelLoaded ? "モデル読み込み済み" : "モデル未読み込み")
                            .font(.caption)
                        if llmEngine.isModelLoaded {
                            Text("\(llmEngine.modelInfo.name) (\(llmEngine.modelInfo.size))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button("モデル選択") {
                        showFilePicker = true
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                
                // チャット画面
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                        .onChange(of: messages.count) { _ in
                            withAnimation {
                                proxy.scrollTo(messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 入力エリア
                HStack {
                    TextField("メッセージを入力...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(llmEngine.isGenerating || !llmEngine.isModelLoaded)
                    
                    if llmEngine.isGenerating {
                        Button(action: stopGeneration) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(canSend ? .blue : .gray)
                        }
                        .disabled(!canSend)
                    }
                }
                .padding()
            }
            .navigationTitle("Qwen3 Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("クリア") {
                        messages = [Message(content: "会話をクリアしました。", isUser: false)]
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("エラー", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            checkForBundledModel()
        }
    }
    
    var canSend: Bool {
        !inputText.isEmpty && !llmEngine.isGenerating && llmEngine.isModelLoaded
    }
    
    func sendMessage() {
        let userMessage = Message(content: inputText, isUser: true)
        messages.append(userMessage)
        let userInput = inputText
        inputText = ""
        
        // AIメッセージのプレースホルダーを追加
        let aiMessage = Message(content: "", isUser: false)
        messages.append(aiMessage)
        let aiMessageId = aiMessage.id
        
        // 生成開始時刻
        let startTime = Date()
        var tokenCount = 0
        
        currentTask = Task {
            do {
                let stream = try await llmEngine.generate(prompt: userInput)
                
                for try await token in stream {
                    tokenCount += 1
                    
                    // メッセージを更新
                    if let index = messages.firstIndex(where: { $0.id == aiMessageId }) {
                        messages[index].content += token
                        
                        // トークン/秒を計算
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed > 0 {
                            messages[index].tokensPerSecond = Double(tokenCount) / elapsed
                        }
                    }
                }
            } catch {
                if let index = messages.firstIndex(where: { $0.id == aiMessageId }) {
                    messages[index].content = "エラー: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        llmEngine.stopGeneration()
    }
    
    func checkForBundledModel() {
        // バンドル内のモデルファイルをチェック
        if let bundlePath = Bundle.main.path(forResource: "qwen3-1.7b-q4_0", ofType: "gguf") {
            Task {
                do {
                    try await llmEngine.loadModel(from: bundlePath)
                    messages.append(Message(
                        content: "バンドル内のモデルを読み込みました。",
                        isUser: false
                    ))
                } catch {
                    messages.append(Message(
                        content: "モデル読み込みエラー: \(error.localizedDescription)",
                        isUser: false
                    ))
                }
            }
        } else {
            messages.append(Message(
                content: "アプリに組み込まれたQwen3 1.7Bモデルを使用します。",
                isUser: false
            ))
        }
    }
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // ファイルサイズチェック
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let sizeMB = Double(fileSize) / 1024 / 1024
                
                if sizeMB > 100 {
                    Task {
                        do {
                            try await llmEngine.loadModel(from: url.path)
                            messages.append(Message(
                                content: "モデルファイル（\(String(format: "%.0f", sizeMB)) MB）を読み込みました。",
                                isUser: false
                            ))
                        } catch {
                            alertMessage = "モデル読み込みエラー: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                } else {
                    alertMessage = "ファイルサイズが小さすぎます。正しいGGUFモデルファイルを選択してください。"
                    showingAlert = true
                }
            } catch {
                alertMessage = "ファイル情報の取得に失敗しました: \(error.localizedDescription)"
                showingAlert = true
            }
            
        case .failure(let error):
            alertMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct Message: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    var tokensPerSecond: Double? = nil
    let timestamp = Date()
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            HStack {
                if message.isUser { Spacer() }
                
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                if !message.isUser { Spacer() }
            }
            
            if let tokensPerSecond = message.tokensPerSecond {
                Text("\(String(format: "%.1f", tokensPerSecond)) tok/s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}