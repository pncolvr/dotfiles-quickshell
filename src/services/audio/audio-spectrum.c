#include <errno.h>
#include <math.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include "vendor/cavacore/cavacore.h"

#define RATE 48000
#define MAX_BANDS 128
#define MAX_SAMPLES 8192

struct spectrum {
    struct pw_main_loop *loop;
    struct pw_stream *stream;
    struct cava_plan *plan;
    double input[MAX_SAMPLES * 2];
    double output[MAX_BANDS * 2];
    int count, bands, fps, failed;
};

static void emit_frame(struct spectrum *s) {
    cava_execute(s->input, s->count, s->output, s->plan);
    for (int i = 0; i < s->bands; i++) {
        double stereo = (s->output[i] + s->output[i + s->bands]) / 2;
        double value = isfinite(stereo) ? fmax(0, fmin(1, stereo)) : 0;
        printf("%s%d", i ? ";" : "", (int)lround(value * 1000));
    }
    putchar('|');
    // CAVA's waveform view uses the most recent signed PCM samples, rather than FFT bands.
    int frames = s->count / 2;
    for (int i = 0; i < s->bands; i++) {
        int frame = frames - s->bands + i;
        double value = frame < 0 ? 0 : (s->input[frame * 2] + s->input[frame * 2 + 1]) / 65536.0;
        printf("%s%d", i ? ";" : "", (int)lround(fmax(-1, fmin(1, value)) * 1000));
    }
    s->count = 0;
    putchar('\n');
    fflush(stdout);
    if (ferror(stdout) && s->loop) pw_main_loop_quit(s->loop);
}

static void append_pcm(struct spectrum *s, const int16_t *pcm, size_t frames) {
    // Bound the queue to the newest samples if capture outruns a display update.
    if (frames > MAX_SAMPLES) {
        pcm += (frames - MAX_SAMPLES) * 2;
        frames = MAX_SAMPLES;
    }
    if (s->count + frames * 2 > MAX_SAMPLES * 2) {
        size_t drop = s->count + frames * 2 - MAX_SAMPLES * 2;
        memmove(s->input, s->input + drop, (s->count - drop) * sizeof(double));
        s->count -= drop;
    }
    for (size_t i = 0; i < frames * 2; i++)
        s->input[s->count++] = pcm[i];
}

static void process_audio(void *userdata) {
    struct spectrum *s = userdata;
    struct pw_buffer *buffer;
    while ((buffer = pw_stream_dequeue_buffer(s->stream))) {
        struct spa_data *data = &buffer->buffer->datas[0];
        if (data->data && data->chunk && data->chunk->offset < data->maxsize) {
            size_t size = SPA_MIN(data->chunk->size, data->maxsize - data->chunk->offset);
            const int16_t *pcm = (const int16_t *)((uint8_t *)data->data + data->chunk->offset);
            append_pcm(s, pcm, size / (sizeof(int16_t) * 2));
        }
        pw_stream_queue_buffer(s->stream, buffer);
    }
}

static void tick(void *userdata, uint64_t expirations) {
    (void)expirations;
    struct spectrum *s = userdata;
    if (!s->count) {
        // Feed silence rather than repeatedly analysing the previous audio frame.
        s->count = RATE / s->fps * 2;
        memset(s->input, 0, s->count * sizeof(double));
    }
    emit_frame(s);
}

static void quit_loop(void *userdata, int signal_number) {
    (void)signal_number;
    struct spectrum *s = userdata;
    pw_main_loop_quit(s->loop);
}

static void stream_state(void *userdata, enum pw_stream_state old,
                         enum pw_stream_state state, const char *error) {
    (void)old;
    struct spectrum *s = userdata;
    if (state == PW_STREAM_STATE_ERROR) {
        fprintf(stderr, "Could not capture the media stream: %s\n", error ? error : "PipeWire error");
        s->failed = 1;
        pw_main_loop_quit(s->loop);
    }
}

static const struct pw_stream_events events = {
    .version = PW_VERSION_STREAM_EVENTS,
    .state_changed = stream_state,
    .process = process_audio,
};

static int integer(const char *text, long minimum, long maximum) {
    char *end;
    errno = 0;
    long value = strtol(text, &end, 10);
    if (errno || !*text || *end || value < minimum || value > maximum) return -1;
    return (int)value;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: audio-spectrum NODE_SERIAL|--stdin BANDS FPS\n");
        return 2;
    }
    struct spectrum s = {0};
    s.bands = integer(argv[2], 8, MAX_BANDS);
    s.fps = integer(argv[3], 10, 60);
    bool from_stdin = !strcmp(argv[1], "--stdin");
    if (s.bands < 0 || s.fps < 0 || (!from_stdin && strspn(argv[1], "0123456789") != strlen(argv[1])) || !*argv[1]) {
        fprintf(stderr, "Invalid spectrum capture arguments\n");
        return 2;
    }
    s.plan = cava_init(s.bands, RATE, 2, 1, 0.77, 50, 10000);
    if (!s.plan || s.plan->status) {
        fprintf(stderr, "Could not initialize cavacore: %s\n", s.plan ? s.plan->error_message : "out of memory");
        free(s.plan);
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);
    if (from_stdin) {
        // Deterministic PCM input for frequency-selectivity tests (s16 stereo, 48 kHz).
        int16_t pcm[RATE / 10 * 2];
        size_t frames;
        while ((frames = fread(pcm, sizeof(int16_t) * 2, RATE / s.fps, stdin))) {
            append_pcm(&s, pcm, frames);
            emit_frame(&s);
            if (ferror(stdout)) break;
        }
    } else {
        pw_init(NULL, NULL);
        s.loop = pw_main_loop_new(NULL);
        if (!s.loop) { cava_destroy(s.plan); return 1; }
        struct pw_loop *loop = pw_main_loop_get_loop(s.loop);
        pw_loop_add_signal(loop, SIGTERM, quit_loop, &s);
        pw_loop_add_signal(loop, SIGINT, quit_loop, &s);
        pw_loop_add_signal(loop, SIGPIPE, quit_loop, &s);
        struct pw_properties *props = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio", PW_KEY_MEDIA_CATEGORY, "Monitor",
            PW_KEY_MEDIA_NAME, "Media spectrum", PW_KEY_APP_NAME, "Quickshell Spectrum Detect",
            PW_KEY_NODE_NAME, "quickshell-spectrum-monitor",
            PW_KEY_STREAM_MONITOR, "true", PW_KEY_NODE_PASSIVE, "true",
            "node.dont-fallback", "true", "node.dont-reconnect", "true",
            PW_KEY_TARGET_OBJECT, argv[1], NULL);
        s.stream = pw_stream_new_simple(loop, "quickshell-spectrum-monitor", props, &events, &s);
        uint8_t pod_buffer[1024];
        struct spa_pod_builder builder = SPA_POD_BUILDER_INIT(pod_buffer, sizeof(pod_buffer));
        struct spa_audio_info_raw format = SPA_AUDIO_INFO_RAW_INIT(
            .format = SPA_AUDIO_FORMAT_S16, .rate = RATE, .channels = 2,
            .position = {SPA_AUDIO_CHANNEL_FL, SPA_AUDIO_CHANNEL_FR});
        const struct spa_pod *params[] = {spa_format_audio_raw_build(&builder, SPA_PARAM_EnumFormat, &format)};
        // Without RT_PROCESS, capture callbacks and FFT timer share the main loop.
        int result = s.stream ? pw_stream_connect(s.stream, PW_DIRECTION_INPUT, PW_ID_ANY,
            PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS, params, 1) : -ENOMEM;
        if (result < 0) {
            fprintf(stderr, "Could not connect the media stream: %s\n", strerror(-result));
            s.failed = 1;
        } else {
            struct spa_source *timer = pw_loop_add_timer(loop, tick, &s);
            struct timespec interval = {.tv_nsec = 1000000000 / s.fps};
            struct timespec first = {.tv_nsec = 1};
            pw_loop_update_timer(loop, timer, &first, &interval, false);
            pw_main_loop_run(s.loop);
        }
        if (s.stream) pw_stream_destroy(s.stream);
        pw_main_loop_destroy(s.loop);
        pw_deinit();
    }
    cava_destroy(s.plan);
    return s.failed || ferror(stdout) ? 1 : 0;
}
