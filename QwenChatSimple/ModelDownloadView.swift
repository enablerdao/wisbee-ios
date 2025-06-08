import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var downloader: ModelDownloader
    @ObservedObject var llmEngine: LLMEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("モデルダウンロード")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Qwen3-1.7Bモデルを高速分割ダウンロード")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // モデル状態
                HStack {
                    Image(systemName: downloader.isModelAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundColor(downloader.isModelAvailable ? .green : .orange)
                    
                    VStack(alignment: .leading) {
                        Text(downloader.isModelAvailable ? "モデルは利用可能です" : "モデルが必要です")
                            .font(.headline)
                        Text(downloader.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // ダウンロードボタン
                if !downloader.isModelAvailable && !downloader.isDownloading {
                    VStack(spacing: 16) {
                        Button(action: startChunkDownload) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down")
                                Text("Qwen3-1.7B 分割ダウンロード")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Text("⚡ 高速分割ダウンロード（約1.0GB）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 7個のチャンクに分割\n• 並列ダウンロードで高速化\n• ネットワーク中断時に再開可能")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }
                
                // ダウンロード進行状況
                if downloader.isDownloading {
                    VStack(spacing: 16) {
                        // メインプログレスバー
                        VStack(spacing: 8) {
                            HStack {
                                Text("ダウンロード進行状況")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(downloader.downloadProgress * 100))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            ProgressView(value: downloader.downloadProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .scaleEffect(1.3)
                        }
                        
                        // 状態メッセージ
                        VStack(spacing: 4) {
                            Text(downloader.statusMessage)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                            
                            if downloader.downloadProgress > 0 {
                                Text("🚀 高速並列ダウンロード中...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // チャンク進捗表示
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "square.stack.3d.up")
                                    .foregroundColor(.blue)
                                Text("チャンク進捗")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                ForEach(1...7, id: \.self) { chunkIndex in
                                    VStack(spacing: 2) {
                                        Circle()
                                            .fill(chunkIndex <= Int(downloader.downloadProgress * 7) + 1 ? Color.green : Color.gray.opacity(0.3))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Text("\(chunkIndex)")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                        Text("Part\(chunkIndex)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        
                        Button("キャンセル") {
                            downloader.cancelDownload()
                        }
                        .foregroundColor(.red)
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // 完了状態
                if downloader.isModelAvailable && !downloader.isDownloading {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("ダウンロード完了！")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Button(action: loadModel) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("モデルを読み込む")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(llmEngine.isModelLoaded)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 技術詳細
                VStack(alignment: .leading, spacing: 8) {
                    Text("技術仕様")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow(label: "モデル", value: "Qwen3-1.7B Q4_0")
                        InfoRow(label: "サイズ", value: "約1.0GB")
                        InfoRow(label: "チャンク数", value: "7個")
                        InfoRow(label: "並列DL", value: "最大3同時")
                        InfoRow(label: "保存先", value: "アプリDocuments")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .navigationTitle("モデル管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .alert("エラー", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func startChunkDownload() {
        print("🚀 ダウンロード開始ボタンが押されました")
        Task {
            do {
                print("📥 downloadModelChunks() を呼び出し中...")
                try await downloader.downloadModelChunks()
                print("✅ ダウンロード完了")
            } catch {
                print("❌ ダウンロードエラー: \(error)")
                alertMessage = "ダウンロードエラー: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    func loadModel() {
        Task {
            do {
                try await llmEngine.loadModelFromDownloader(downloader)
                dismiss()
            } catch {
                alertMessage = "モデル読み込みエラー: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

struct InfoRow: View {
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

struct ModelDownloadView_Previews: PreviewProvider {
    static var previews: some View {
        ModelDownloadView(
            downloader: ModelDownloader(),
            llmEngine: LLMEngine.shared
        )
    }
}