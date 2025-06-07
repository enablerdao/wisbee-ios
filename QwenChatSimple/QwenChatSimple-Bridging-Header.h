//
//  QwenChatSimple-Bridging-Header.h
//  QwenChatSimple
//

#ifndef QwenChatSimple_Bridging_Header_h
#define QwenChatSimple_Bridging_Header_h

// Import llama.cpp headers
#ifdef __cplusplus
extern "C" {
#endif

// For now, we'll define minimal structures to avoid needing the full llama.cpp
// This is a placeholder until we properly integrate llama.cpp

typedef struct llama_model llama_model;
typedef struct llama_context llama_context;

// Minimal function declarations
struct llama_model* llama_load_model_from_file(const char* path_model);
struct llama_context* llama_new_context_with_model(struct llama_model* model);
void llama_free_model(struct llama_model* model);
void llama_free(struct llama_context* ctx);

#ifdef __cplusplus
}
#endif

#endif /* QwenChatSimple_Bridging_Header_h */