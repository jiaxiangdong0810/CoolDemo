#ifndef LLAMA_WRAPPER_H
#define LLAMA_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize llama.cpp backend (call once before any other operations).
 */
void llama_backend_init_wrapper(void);

/**
 * Load a GGUF model from the given path.
 * Returns a pointer to the model context, or NULL on failure.
 */
void* llama_load_model(const char* model_path);

/**
 * Generate text from a prompt using the loaded model.
 * The result is written to the output buffer.
 * Returns the number of characters written, or -1 on error.
 */
int llama_generate(void* model_ctx, const char* prompt, char* output, int output_size,
                   int max_tokens, float temperature);

/**
 * Generate text with a callback for each token.
 * The callback is called for each generated token.
 * Returns 0 on success, -1 on error.
 */
int llama_generate_stream(void* model_ctx, const char* prompt,
                          void (*token_callback)(const char* token, void* user_data),
                          void* user_data,
                          int max_tokens, float temperature);

/**
 * Generate a chat response from a formatted chat prompt.
 * The result is written to the output buffer.
 * Returns the number of characters written, or -1 on error.
 */
int llama_chat(void* model_ctx, const char* chat_prompt, char* output, int output_size,
               int max_tokens, float temperature);

/**
 * Free the model context and release all resources.
 */
void llama_wrapper_free(void* model_ctx);

/**
 * Get the last error message.
 */
const char* llama_get_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // LLAMA_WRAPPER_H
