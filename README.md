# Wisbee iOS - Qwen3 Chat App

A native iOS chat application powered by Qwen3 1.7B language model, running entirely on-device for complete privacy.

## Features

- 🚀 **On-device inference** - No internet connection required
- 🔒 **Complete privacy** - All processing happens locally
- 💬 **Native iOS experience** - Built with SwiftUI
- ⚡ **Optimized performance** - 15-18 tokens/second on iPhone 15 Pro
- 📱 **Universal support** - Works on iPhone and iPad

## Model

This app uses Qwen3 1.7B quantized model (Q4_0):
- Model size: 1.0GB
- Context length: 2048 tokens
- Optimized for mobile devices

## Requirements

- iOS 14.0+
- Xcode 14.0+
- 2GB+ free storage

## Building

1. Clone the repository
2. Open `QwenChatSimple.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on device or simulator

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Qwen team for the excellent language model
- llama.cpp for the inference engine