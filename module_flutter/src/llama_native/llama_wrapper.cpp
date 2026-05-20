#include "llama_wrapper.h"
#include <llama.h>
#include <atomic>
#include <string>
#include <vector>
#include <cstring>

#include <android/log.h>
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "LLAMA_WRAPPER", __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "LLAMA_WRAPPER", __VA_ARGS__)

static std::string g_last_error;
static bool g_backend_initialized = false;
static std::atomic<bool> g_stop_flag{false};

void llama_set_stop_flag(int flag) {
    LOGI("llama_set_stop_flag called: %d", flag);
    g_stop_flag.store(flag != 0);
}

static void set_error(const char* msg) {
    g_last_error = msg;
}

const char* llama_get_last_error(void) {
    return g_last_error.c_str();
}

void llama_backend_init_wrapper(void) {
    if (!g_backend_initialized) {
        llama_backend_init();
        g_backend_initialized = true;
    }
}

// Helper: add a single token to a batch
static void batch_add_token(
    llama_batch& batch,
    llama_token id,
    llama_pos pos,
    bool logits
) {
    batch.token [batch.n_tokens] = id;
    batch.pos   [batch.n_tokens] = pos;
    batch.n_seq_id[batch.n_tokens] = 1;
    batch.seq_id[batch.n_tokens][0] = 0;
    batch.logits[batch.n_tokens] = logits ? 1 : 0;
    batch.n_tokens++;
}

// Helper: clear batch (reset token count)
static void batch_clear(llama_batch& batch) {
    batch.n_tokens = 0;
}

void* llama_load_model(const char* model_path) {
    if (!model_path) {
        set_error("model_path is null");
        return nullptr;
    }

    // Ensure backend is initialized
    llama_backend_init_wrapper();

    llama_model_params model_params = llama_model_default_params();

    llama_model* model = llama_model_load_from_file(model_path, model_params);
    if (!model) {
        set_error("failed to load model");
        return nullptr;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx   = 2048;
    ctx_params.n_batch = 512;
    ctx_params.n_ubatch = 512;

    llama_context* ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        llama_model_free(model);
        set_error("failed to create context");
        return nullptr;
    }

    return ctx;
}

void llama_wrapper_free(void* model_ctx) {
    if (!model_ctx) return;

    llama_context* ctx = static_cast<llama_context*>(model_ctx);
    // llama_free also frees the associated model internally in recent llama.cpp
    llama_free(ctx);
}

static int generate_internal(
    llama_context* ctx,
    const char* prompt,
    void (*token_callback)(const char* token, void* user_data),
    void* user_data,
    int max_tokens,
    float temperature,
    char* output,
    int output_size
) {
    if (!ctx || !prompt) {
        set_error("invalid context or prompt");
        return -1;
    }

    const llama_model* model = llama_get_model(ctx);
    const llama_vocab* vocab = llama_model_get_vocab(model);

    // Clear memory (KV cache) so each generation starts fresh
    llama_memory_clear(llama_get_memory(ctx), true);

    // Tokenize prompt
    const size_t prompt_len = std::strlen(prompt);
    std::vector<llama_token> tokens;
    tokens.resize(prompt_len + 16);

    int32_t n_tokens = llama_tokenize(
        vocab,
        prompt,
        static_cast<int32_t>(prompt_len),
        tokens.data(),
        static_cast<int32_t>(tokens.size()),
        true,   // add_special
        false   // parse_special
    );

    if (n_tokens < 0) {
        set_error("tokenization failed");
        return -1;
    }
    tokens.resize(static_cast<size_t>(n_tokens));

    // Build sampler chain:
    // penalties -> top_k -> top_p -> temp -> dist
    // Repeat penalty is crucial to prevent repetitive output loops
    llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());

    // Repeat penalty: penalize tokens that already appeared in the context
    // repeat_last_n = 64: look at last 64 tokens for repetition
    // repeat_penalty = 1.1: moderate penalty (1.0 = no penalty, >1.0 = penalize repeats)
    // frequency_penalty = 0.0: no frequency penalty
    // presence_penalty = 0.0: no presence penalty
    llama_sampler_chain_add(sampler, llama_sampler_init_penalties(64, 1.10f, 0.0f, 0.0f));

    // Top-k sampling: only consider top 40 tokens by probability
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40));

    // Top-p (nucleus) sampling: sample from tokens whose cumulative prob >= 0.9
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9f, 1));

    // Temperature: controls randomness (higher = more random)
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));

    // Dist: random sampling from the filtered distribution
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    std::string result;
    llama_pos n_cur = 0;

    // Reset stop flag at the start of each generation
    LOGI("generate_internal: resetting stop flag");
    g_stop_flag.store(false);

    // Create batch (max 512 tokens, 1 sequence)
    llama_batch batch = llama_batch_init(512, 0, 1);

    // Feed prompt tokens into the model
    for (size_t i = 0; i < tokens.size(); i++) {
        bool is_last = (i == tokens.size() - 1);
        batch_add_token(batch, tokens[i], n_cur++, is_last);
    }

    if (llama_decode(ctx, batch) != 0) {
        llama_batch_free(batch);
        llama_sampler_free(sampler);
        set_error("decode failed");
        return -1;
    }

    // Generate new tokens
    for (int i = 0; i < max_tokens; i++) {
        if (g_stop_flag.load()) {
            LOGI("generate_internal: stop flag detected, breaking at token %d", i);
            break;
        }

        llama_token new_token_id = llama_sampler_sample(sampler, ctx, -1);

        if (llama_vocab_is_eog(vocab, new_token_id)) {
            break;
        }

        char piece_buf[256];
        int32_t n_piece = llama_token_to_piece(
            vocab,
            new_token_id,
            piece_buf,
            sizeof(piece_buf),
            0,      // lstrip
            true    // special
        );

        if (n_piece > 0) {
            std::string token_str(piece_buf, static_cast<size_t>(n_piece));

            // Stop generation if we encounter Qwen chat template end markers
            // This prevents the model from generating beyond the intended response
            if (token_str.find("<|im_end|>") != std::string::npos ||
                token_str.find("<|im_start|>") != std::string::npos ||
                token_str.find("<|endoftext|>") != std::string::npos) {
                LOGI("generate_internal: stop token detected, breaking");
                break;
            }

            result += token_str;

            if (token_callback) {
                token_callback(token_str.c_str(), user_data);
            }
        }

        // Feed the newly generated token back for next iteration
        batch_clear(batch);
        batch_add_token(batch, new_token_id, n_cur++, true);

        if (llama_decode(ctx, batch) != 0) {
            break;
        }
    }

    llama_batch_free(batch);
    llama_sampler_free(sampler);

    if (output && output_size > 0) {
        int32_t copy_len = static_cast<int32_t>(
            result.length() < static_cast<size_t>(output_size - 1)
                ? result.length()
                : static_cast<size_t>(output_size - 1)
        );
        std::memcpy(output, result.c_str(), static_cast<size_t>(copy_len));
        output[copy_len] = '\0';
        return copy_len;
    }

    return static_cast<int>(result.length());
}

int llama_generate(
    void* model_ctx,
    const char* prompt,
    char* output,
    int output_size,
    int max_tokens,
    float temperature
) {
    if (!model_ctx) {
        set_error("model not loaded");
        return -1;
    }
    return generate_internal(
        static_cast<llama_context*>(model_ctx),
        prompt,
        nullptr, nullptr,
        max_tokens, temperature,
        output, output_size
    );
}

int llama_generate_stream(
    void* model_ctx,
    const char* prompt,
    void (*token_callback)(const char* token, void* user_data),
    void* user_data,
    int max_tokens,
    float temperature
) {
    if (!model_ctx) {
        set_error("model not loaded");
        return -1;
    }
    return generate_internal(
        static_cast<llama_context*>(model_ctx),
        prompt,
        token_callback, user_data,
        max_tokens, temperature,
        nullptr, 0
    );
}

int llama_chat(
    void* model_ctx,
    const char* chat_prompt,
    char* output,
    int output_size,
    int max_tokens,
    float temperature
) {
    return llama_generate(
        model_ctx, chat_prompt, output, output_size, max_tokens, temperature
    );
}
