/**
 * PCIe DMA Benchmark Tool
 * Optimized version with enhanced readability and maintainability
 */

#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <linux/input.h>
#include <errno.h>
#include <string.h>
#include <getopt.h>
#include <stdbool.h>
#include <libgen.h>
#include <sys/select.h>
#include <signal.h>

#define DMA_DEVICE_PATH     "/dev/pcie_dma_memcpy"
#define VERSION_STRING      "2.0"
#define DEFAULT_TIMEOUT_MS  1000
#define BUFFER_ALIGNMENT    64

/* IOCTL Command Codes */
enum DMA_COMMANDS {
    DMA_CMD_SETUP      = 0x01000000,
    DMA_CMD_START      = 0x02000000,
    DMA_CMD_GET_TIMING = 0x03000000,
    DMA_CMD_SHUTDOWN   = 0x04000000
};

typedef struct {
    uint32_t device_address;
    uint32_t transfer_size;
    uint32_t test_cycles;
    char input_device[64];
} AppConfig;

typedef struct {
    uint32_t src_phys_addr;
    uint32_t dst_phys_addr;
    uint32_t direction;
    uint32_t chunk_size;
    uint32_t total_size;
} DMAConfig;

typedef struct {
    float dma_read_rate;
    float dma_write_rate;
    float cpu_read_rate;
    float cpu_write_rate;
    uint32_t dma_read_time;
    uint32_t dma_write_time;
    uint32_t cpu_read_time;
    uint32_t cpu_write_time;
    uint32_t error_count;
} BenchmarkMetrics;

typedef struct {
    int dma_fd;
    int input_fd;
    void* mapped_memory;
    AppConfig config;
    BenchmarkMetrics metrics;
} DMAContext;

/* Global control flag */
volatile bool g_terminate = false;

static const char short_options[] = ":a:d:s:c:vh";
static const struct option long_options[] = {
    { "device",     required_argument,  NULL, 'd' },
    { "address",    required_argument,  NULL, 'a' },
    { "size",       required_argument,  NULL, 's' },
    { "cycles",     required_argument,  NULL, 'c' },
    { "version",    no_argument,        NULL, 'v' },
    { "help",       no_argument,        NULL, 'h' },
    { NULL, 0, NULL, 0 }
};

/* Function prototypes */
static void show_usage(char **argv);
static bool parse_arguments(AppConfig *config, int argc, char **argv);
static void signal_handler(int signal);
static int initialize_dma(DMAContext *ctx);
static void cleanup_resources(DMAContext *ctx);
static int perform_write_test(DMAContext *ctx, uint16_t *write_buf);
static int perform_read_test(DMAContext *ctx, uint16_t *write_buf, uint16_t *read_buf);
static void aligned_memcpy(void* dest, void* src, size_t size);
static void execute_benchmark(DMAContext *ctx);

static void show_usage(char **argv) {
    fprintf(stdout,
        "PCIe DMA Benchmark Tool\n\n"
        "Usage: %s [options]\n\n"
        "Options:\n"
        " -a | --address        Target physical address (hex)\n"
        " -s | --size           Transfer size in bytes\n"
        " -c | --cycles         Test iterations\n"
        " -d | --device         Input device path\n"
        " -v | --version        Show version\n"
        " -h | --help           Show this help\n\n"
        "Example:\n"
        "  %s -a 0x01000000 -s 2048 -c 1000 -d /dev/input/event2\n",
        basename(argv[0]), basename(argv[0]));
}

static bool parse_arguments(AppConfig *config, int argc, char **argv) {
    memset(config, 0, sizeof(AppConfig));
    int opt;

    while ((opt = getopt_long(argc, argv, short_options, long_options, NULL)) != -1) {
        switch (opt) {
        case 'a':
            config->device_address = strtoul(optarg, NULL, 16);
            break;
        case 's':
            config->transfer_size = atoi(optarg);
            break;
        case 'c':
            config->test_cycles = atoi(optarg);
            break;
        case 'd':
            strncpy(config->input_device, optarg, sizeof(config->input_device)-1);
            break;
        case 'v':
            printf("Version: %s\n", VERSION_STRING);
            exit(EXIT_SUCCESS);
        case 'h':
            show_usage(argv);
            exit(EXIT_SUCCESS);
        default:
            fprintf(stderr, "Invalid option: -%c\n", optopt);
            return false;
        }
    }

    if (!config->device_address || !config->transfer_size || 
        !config->test_cycles || !strlen(config->input_device)) {
        fprintf(stderr, "Missing required parameters\n");
        return false;
    }
    return true;
}

static void signal_handler(int signal) {
    g_terminate = true;
}

static int initialize_dma(DMAContext *ctx) {
    // Open DMA device
    if ((ctx->dma_fd = open(DMA_DEVICE_PATH, O_RDWR)) < 0) {
        perror("DMA device open failed");
        return -1;
    }

    // Open input device
    if ((ctx->input_fd = open(ctx->config.input_device, O_RDONLY | O_NONBLOCK)) < 0) {
        perror("Input device open failed");
        close(ctx->dma_fd);
        return -1;
    }

    printf("DMA and input devices opened successfully\n");
    return 0;
}

static void cleanup_resources(DMAContext *ctx) {
    if (ctx->mapped_memory) {
        munmap(ctx->mapped_memory, ctx->config.transfer_size);
    }
    if (ctx->dma_fd != -1) close(ctx->dma_fd);
    if (ctx->input_fd != -1) close(ctx->input_fd);
}

static void aligned_memcpy(void* dest, void* src, size_t size) {
    /* 64-byte aligned memory copy using NEON instructions */
    if (size & (BUFFER_ALIGNMENT-1)) {
        size = (size & -BUFFER_ALIGNMENT) + BUFFER_ALIGNMENT;
    }

    asm volatile (
        "sub %[dst], %[dst], #64 \n"
        "1: \n"
        "ldnp q0, q1, [%[src]] \n"
        "ldnp q2, q3, [%[src], #32] \n"
        "add %[dst], %[dst], #64 \n"
        "subs %[sz], %[sz], #64 \n"
        "add %[src], %[src], #64 \n"
        "stnp q0, q1, [%[dst]] \n"
        "stnp q2, q3, [%[dst], #32] \n"
        "b.gt 1b \n"
        : [dst]"+r"(dest), [src]"+r"(src), [sz]"+r"(size)
        : 
        : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", "cc", "memory");
}

static int perform_write_test(DMAContext *ctx, uint16_t *write_buf) {
    DMAConfig cfg = {
        .src_phys_addr = ctx->config.device_address,
        .total_size = ctx->config.transfer_size,
        .chunk_size = ctx->config.transfer_size,
        .direction = 0 // Write operation
    };

    // Setup DMA transfer
    uint32_t dev_addr = ioctl(ctx->dma_fd, DMA_CMD_SETUP, &cfg);
    if (!dev_addr) {
        fprintf(stderr, "DMA setup failed\n");
        return -1;
    }

    // Map memory for DMA
    ctx->mapped_memory = mmap(NULL, cfg.total_size, 
                            PROT_READ | PROT_WRITE, 
                            MAP_SHARED, ctx->dma_fd, 0);
    if (ctx->mapped_memory == MAP_FAILED) {
        perror("Memory mapping failed");
        return -1;
    }

    // Perform memory copy and measure time
    struct timeval start, end;
    gettimeofday(&start, NULL);
    aligned_memcpy(ctx->mapped_memory, write_buf, cfg.total_size);
    gettimeofday(&end, NULL);

    // Calculate metrics
    timersub(&end, &start, &end);
    ctx->metrics.cpu_write_time = end.tv_sec * 1000000 + end.tv_usec;
    ctx->metrics.cpu_write_rate = (cfg.total_size / (ctx->metrics.cpu_write_time / 1000000.0)) / (1024 * 1024);

    // Start DMA transfer
    if (ioctl(ctx->dma_fd, DMA_CMD_START, 0) < 0) {
        perror("DMA start failed");
        munmap(ctx->mapped_memory, cfg.total_size);
        return -1;
    }

    // Wait for completion
    fd_set fds;
    struct timeval timeout = { .tv_sec = 1 };
    FD_ZERO(&fds);
    FD_SET(ctx->input_fd, &fds);

    int ret = select(ctx->input_fd+1, &fds, NULL, NULL, &timeout);
    if (ret <= 0) {
        fprintf(stderr, "DMA write timeout\n");
        ioctl(ctx->dma_fd, DMA_CMD_SHUTDOWN, 0);
        munmap(ctx->mapped_memory, cfg.total_size);
        return -1;
    }

    // Get DMA timing
    ctx->metrics.dma_write_time = ioctl(ctx->dma_fd, DMA_CMD_GET_TIMING, 0);
    ctx->metrics.dma_write_rate = (cfg.total_size / (ctx->metrics.dma_write_time / 1000000.0)) / (1024 * 1024);

    // Cleanup
    munmap(ctx->mapped_memory, cfg.total_size);
    return ioctl(ctx->dma_fd, DMA_CMD_SHUTDOWN, 0);
}

static int perform_read_test(DMAContext *ctx, uint16_t *write_buf, uint16_t *read_buf) {
    DMAConfig cfg = {
        .src_phys_addr = ctx->config.device_address,
        .total_size = ctx->config.transfer_size,
        .chunk_size = ctx->config.transfer_size,
        .direction = 1 // Read operation
    };

    // Setup DMA transfer
    uint32_t dev_addr = ioctl(ctx->dma_fd, DMA_CMD_SETUP, &cfg);
    if (!dev_addr) {
        fprintf(stderr, "DMA setup failed\n");
        return -1;
    }

    // Start DMA transfer
    if (ioctl(ctx->dma_fd, DMA_CMD_START, 0) < 0) {
        perror("DMA start failed");
        return -1;
    }

    // Wait for completion
    fd_set fds;
    struct timeval timeout = { .tv_sec = 1 };
    FD_ZERO(&fds);
    FD_SET(ctx->input_fd, &fds);

    int ret = select(ctx->input_fd+1, &fds, NULL, NULL, &timeout);
    if (ret <= 0) {
        fprintf(stderr, "DMA read timeout\n");
        ioctl(ctx->dma_fd, DMA_CMD_SHUTDOWN, 0);
        return -1;
    }

    // Map memory for access
    ctx->mapped_memory = mmap(NULL, cfg.total_size, 
                            PROT_READ | PROT_WRITE, 
                            MAP_SHARED, ctx->dma_fd, 0);
    if (ctx->mapped_memory == MAP_FAILED) {
        perror("Memory mapping failed");
        return -1;
    }

    // Perform memory copy and measure time
    struct timeval start, end;
    gettimeofday(&start, NULL);
    aligned_memcpy(read_buf, ctx->mapped_memory, cfg.total_size);
    gettimeofday(&end, NULL);

    // Calculate metrics
    timersub(&end, &start, &end);
    ctx->metrics.cpu_read_time = end.tv_sec * 1000000 + end.tv_usec;
    ctx->metrics.cpu_read_rate = (cfg.total_size / (ctx->metrics.cpu_read_time / 1000000.0)) / (1024 * 1024);

    // Verify data integrity
    for (int i = 0; i < cfg.total_size/2; i++) {
        if (read_buf[i] != write_buf[i]) {
            ctx->metrics.error_count++;
#ifdef DEBUG
            fprintf(stderr, "Data mismatch at %d: 0x%04X vs 0x%04X\n", 
                    i, write_buf[i], read_buf[i]);
#endif
        }
    }

    // Get DMA timing
    ctx->metrics.dma_read_time = ioctl(ctx->dma_fd, DMA_CMD_GET_TIMING, 0);
    ctx->metrics.dma_read_rate = (cfg.total_size / (ctx->metrics.dma_read_time / 1000000.0)) / (1024 * 1024);

    // Cleanup
    munmap(ctx->mapped_memory, cfg.total_size);
    return ioctl(ctx->dma_fd, DMA_CMD_SHUTDOWN, 0);
}

static void execute_benchmark(DMAContext *ctx) {
    uint16_t *write_buffer = malloc(ctx->config.transfer_size);
    uint16_t *read_buffer = malloc(ctx->config.transfer_size);
    unsigned remaining = ctx->config.test_cycles;

    if (!write_buffer || !read_buffer) {
        perror("Memory allocation failed");
        goto cleanup;
    }

    // Initialize write buffer
    srand(time(NULL));
    for (int i = 0; i < ctx->config.transfer_size/2; i++) {
        write_buffer[i] = rand() % 0xFFFF;
    }

    BenchmarkMetrics totals = {0};
    unsigned completed = 0;

    while (remaining-- && !g_terminate) {
        memset(&ctx->metrics, 0, sizeof(BenchmarkMetrics));

        if (perform_write_test(ctx, write_buffer) < 0) {
            fprintf(stderr, "Write test failed\n");
            continue;
        }

        if (perform_read_test(ctx, write_buffer, read_buffer) < 0) {
            fprintf(stderr, "Read test failed\n");
            continue;
        }

        // Accumulate metrics
        completed++;
        totals.dma_write_time += ctx->metrics.dma_write_time;
        totals.dma_read_time += ctx->metrics.dma_read_time;
        totals.cpu_write_time += ctx->metrics.cpu_write_time;
        totals.cpu_read_time += ctx->metrics.cpu_read_time;
        totals.dma_write_rate += ctx->metrics.dma_write_rate;
        totals.dma_read_rate += ctx->metrics.dma_read_rate;
        totals.cpu_write_rate += ctx->metrics.cpu_write_rate;
        totals.cpu_read_rate += ctx->metrics.cpu_read_rate;
        totals.error_count += ctx->metrics.error_count;

        // Display progress
        printf("\rCompleted: %u/%u cycles | Errors: %u", 
              completed, ctx->config.test_cycles, totals.error_count);
        fflush(stdout);
    }

    // Print final report
    printf("\n\nFinal Report:\n");
    printf("DMA Write: %.2f MB/s (avg)\n", totals.dma_write_rate / completed);
    printf("DMA Read:  %.2f MB/s (avg)\n", totals.dma_read_rate / completed);
    printf("CPU Write: %.2f MB/s (avg)\n", totals.cpu_write_rate / completed);
    printf("CPU Read:  %.2f MB/s (avg)\n", totals.cpu_read_rate / completed);
    printf("Total errors: %u\n", totals.error_count);

cleanup:
    free(write_buffer);
    free(read_buffer);
}

int main(int argc, char *argv[]) {
    AppConfig config;
    DMAContext ctx = {0};

    if (!parse_arguments(&config, argc, argv)) {
        show_usage(argv);
        exit(EXIT_FAILURE);
    }

    signal(SIGINT, signal_handler);
    ctx.config = config;

    if (initialize_dma(&ctx) < 0) {
        exit(EXIT_FAILURE);
    }

    execute_benchmark(&ctx);
    cleanup_resources(&ctx);

    return EXIT_SUCCESS;
}