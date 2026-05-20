#include "llama_wrapper.h"
#include <llama.h>
#include <string>
#include <vector>
#include <cstring>

static std::string g_last_error;
static bool g_backend_initialized = false;

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

    // Build sampler chain: temperature -> dist
    llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    std::string result;
    llama_pos n_cur = 0;

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
