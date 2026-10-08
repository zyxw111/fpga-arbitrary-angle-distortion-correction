#include <stdio.h>
#include <stdbool.h>
#include <getopt.h>
#include <string.h>
#include <libgen.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>

#define TOOL_VERSION    "2.0"
#define DEFAULT_DEVICE  "/dev/spidev4.0"
#define MAX_DEVICE_PATH 64
#define MAX_BUFFER_SIZE (1024 * 1024) // 1MB

typedef enum {
    SPI_MODE_SINGLE = 1,
    SPI_MODE_DUAL,
    SPI_MODE_QUAD
} SpiTransferMode;

typedef struct {
    char device[MAX_DEVICE_PATH];
    uint32_t speed_hz;
    uint32_t transfer_size;
    uint32_t cycle_count;
    uint32_t spi_mode;
    uint8_t bits_per_word;
    uint16_t delay_us;
    SpiTransferMode protocol_mode;
} SpiTestConfig;

typedef struct {
    double tx_rate_mbs;
    double rx_rate_mbs;
    float error_percent;
    uint64_t tx_bytes;
    uint64_t rx_bytes;
    struct timeval time_cost;
} TestResult;

// Function prototypes
static bool parse_arguments(SpiTestConfig* config, int argc, char **argv);
static void show_usage(const char* prog_name);
static int configure_spi_interface(int fd, SpiTestConfig* config);
static void prepare_test_data(uint8_t* buffer, uint32_t size);
static void calculate_transfer_stats(struct timeval* start, struct timeval* end,
                                   uint64_t bytes, bool is_tx, TestResult* result);
static void print_test_results(const TestResult* tx_result, const TestResult* rx_result);
static int perform_transfer(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config);
static int run_single_mode_test(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config);
static int run_dual_mode_test(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config);
static int run_quad_mode_test(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config);
static int validate_data_integrity(uint8_t* tx_buf, uint8_t* rx_buf, uint32_t size);

static const struct option long_options[] = {
    {"device",    required_argument, NULL, 'd'},
    {"delay",     required_argument, NULL, 'D'},
    {"speed",     required_argument, NULL, 's'},
    {"size",      required_argument, NULL, 'S'},
    {"cycles",    required_argument, NULL, 'c'},
    {"cpha",      no_argument,       NULL, 'H'},
    {"cpol",      no_argument,       NULL, 'O'},
    {"bpw",       required_argument, NULL, 'b'},
    {"lsb",       no_argument,       NULL, 'L'},
    {"cs-high",   no_argument,       NULL, 'C'},
    {"3wire",     no_argument,       NULL, '3'},
    {"no-cs",     no_argument,       NULL, 'N'},
    {"ready",     no_argument,       NULL, 'R'},
    {"mode",      required_argument, NULL, 'm'},
    {"version",   no_argument,       NULL, 'v'},
    {"help",      no_argument,       NULL, 'h'},
    {NULL, 0, NULL, 0}
};

int main(int argc, char **argv) {
    SpiTestConfig config = {
        .device = DEFAULT_DEVICE,
        .speed_hz = 0,
        .transfer_size = 0,
        .cycle_count = 0,
        .spi_mode = 0,
        .bits_per_word = 8,
        .delay_us = 0,
        .protocol_mode = SPI_MODE_SINGLE
    };

    if (!parse_arguments(&config, argc, argv)) {
        fprintf(stderr, "Invalid parameters, use --help for usage\n");
        return EXIT_FAILURE;
    }

    int fd = open(config.device, O_RDWR);
    if (fd < 0) {
        perror("Device open failed");
        return EXIT_FAILURE;
    }

    if (configure_spi_interface(fd, &config) != 0) {
        close(fd);
        return EXIT_FAILURE;
    }

    uint8_t* tx_buffer = malloc(config.transfer_size);
    uint8_t* rx_buffer = malloc(config.transfer_size);
    if (!tx_buffer || !rx_buffer) {
        perror("Memory allocation failed");
        free(tx_buffer);
        free(rx_buffer);
        close(fd);
        return EXIT_FAILURE;
    }

    prepare_test_data(tx_buffer, config.transfer_size);
    memset(rx_buffer, 0, config.transfer_size);

    int result = EXIT_SUCCESS;
    switch (config.protocol_mode) {
        case SPI_MODE_SINGLE:
            result = run_single_mode_test(fd, tx_buffer, rx_buffer, &config);
            break;
        case SPI_MODE_DUAL:
            result = run_dual_mode_test(fd, tx_buffer, rx_buffer, &config);
            break;
        case SPI_MODE_QUAD:
            result = run_quad_mode_test(fd, tx_buffer, rx_buffer, &config);
            break;
        default:
            fprintf(stderr, "Unsupported SPI mode\n");
            result = EXIT_FAILURE;
    }

    free(tx_buffer);
    free(rx_buffer);
    close(fd);
    return result;
}

static bool parse_arguments(SpiTestConfig* config, int argc, char **argv) {
    int opt;
    while ((opt = getopt_long(argc, argv, "d:D:s:S:c:b:m:OHL3CNRvh", long_options, NULL)) != -1) {
        switch (opt) {
        case 'd': strncpy(config->device, optarg, MAX_DEVICE_PATH); config->device[MAX_DEVICE_PATH-1] = '\0'; break;
        case 'D': config->delay_us = atoi(optarg); break;
        case 's': config->speed_hz = atoi(optarg); break;
        case 'S': config->transfer_size = atoi(optarg); break;
        case 'c': config->cycle_count = atoi(optarg); break;
        case 'b': config->bits_per_word = atoi(optarg); break;
        case 'm': config->protocol_mode = atoi(optarg); break;
        case 'O': config->spi_mode |= SPI_CPOL; break;
        case 'H': config->spi_mode |= SPI_CPHA; break;
        case 'L': config->spi_mode |= SPI_LSB_FIRST; break;
        case 'C': config->spi_mode |= SPI_CS_HIGH; break;
        case '3': config->spi_mode |= SPI_3WIRE; break;
        case 'N': config->spi_mode |= SPI_NO_CS; break;
        case 'R': config->spi_mode |= SPI_READY; break;
        case 'v': printf("SPI Tool Version: %s\n", TOOL_VERSION); exit(EXIT_SUCCESS);
        case 'h': show_usage(argv[0]); exit(EXIT_SUCCESS);
        default: return false;
        }
    }

    // Validate required parameters
    if (config->speed_hz == 0 || config->transfer_size == 0 || config->cycle_count == 0) {
        fprintf(stderr, "Missing required parameters: speed, size, or cycles\n");
        return false;
    }

    if (config->transfer_size > MAX_BUFFER_SIZE) {
        fprintf(stderr, "Transfer size exceeds maximum limit of %d bytes\n", MAX_BUFFER_SIZE);
        return false;
    }

    return true;
}

static int configure_spi_interface(int fd, SpiTestConfig* config) {
    // Set SPI mode
    if (ioctl(fd, SPI_IOC_WR_MODE32, &config->spi_mode) == -1) {
        perror("Failed to set SPI mode");
        return -1;
    }

    // Set bits per word
    if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &config->bits_per_word) == -1) {
        perror("Failed to set bits per word");
        return -1;
    }

    // Set max speed
    if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &config->speed_hz) == -1) {
        perror("Failed to set SPI speed");
        return -1;
    }

    printf("SPI Configuration:\n");
    printf("  Device: %s\n", config->device);
    printf("  Mode: 0x%08X\n", config->spi_mode);
    printf("  Bits per word: %d\n", config->bits_per_word);
    printf("  Speed: %u Hz (%u KHz)\n", config->speed_hz, config->speed_hz/1000);
    return 0;
}

static int perform_transfer(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config) {
    struct spi_ioc_transfer tr = {
        .tx_buf = (unsigned long)tx_buf,
        .rx_buf = (unsigned long)rx_buf,
        .len = config->transfer_size,
        .delay_usecs = config->delay_us,
        .speed_hz = config->speed_hz,
        .bits_per_word = config->bits_per_word,
    };

    // Configure transfer mode
    switch (config->protocol_mode) {
        case SPI_MODE_DUAL:
            tr.tx_nbits = tr.rx_nbits = 2;
            break;
        case SPI_MODE_QUAD:
            tr.tx_nbits = tr.rx_nbits = 4;
            break;
        default:
            tr.tx_nbits = tr.rx_nbits = 1;
    }

    return ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
}

static void calculate_transfer_stats(struct timeval* start, struct timeval* end,
                                   uint64_t bytes, bool is_tx, TestResult* result) {
    struct timeval diff;
    timersub(end, start, &diff);
    
    float seconds = diff.tv_sec + diff.tv_usec / 1000000.0f;
    
    if (is_tx) {
        result->tx_bytes = bytes;
        result->tx_rate_mbs = (bytes / (1024.0 * 1024.0)) / seconds;
    } else {
        result->rx_bytes = bytes;
        result->rx_rate_mbs = (bytes / (1024.0 * 1024.0)) / seconds;
    }
    result->time_cost = diff;
}

static int validate_data_integrity(uint8_t* tx_buf, uint8_t* rx_buf, uint32_t size) {
    uint32_t errors = 0;
    for (uint32_t i = 0; i < size; i++) {
        if (tx_buf[i] != rx_buf[i]) errors++;
    }
    return (errors * 10000) / size; // Returns error percentage * 100 for precision
}

static void print_test_results(const TestResult* tx_result, const TestResult* rx_result) {
    printf("\n=== Test Results ===");
    printf("\nTransfer Time: %.2f ms", 
          (tx_result->time_cost.tv_sec * 1000.0) + 
          (tx_result->time_cost.tv_usec / 1000.0));
    printf("\nTX Throughput: %.2f MB/s", tx_result->tx_rate_mbs);
    printf("\nRX Throughput: %.2f MB/s", rx_result->rx_rate_mbs);
    printf("\nError Rate: %.2f%%\n", rx_result->error_percent);
    printf("====================\n");
}

static void prepare_test_data(uint8_t* buffer, uint32_t size) {
    srand(time(NULL));
    for (uint32_t i = 0; i < size; i++) {
        buffer[i] = rand() % 256;
    }
}

static int run_single_mode_test(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config) {
    TestResult tx_result = {0}, rx_result = {0};
    struct timeval start, end;

    printf("\nStarting Single Mode Test\n");
    gettimeofday(&start, NULL);
    
    for (uint32_t i = 0; i < config->cycle_count; i++) {
        if (perform_transfer(fd, tx_buf, rx_buf, config) < 0) {
            perror("SPI transfer failed");
            return EXIT_FAILURE;
        }
    }
    
    gettimeofday(&end, NULL);
    calculate_transfer_stats(&start, &end, config->transfer_size * config->cycle_count, 
                           true, &tx_result);
    calculate_transfer_stats(&start, &end, config->transfer_size * config->cycle_count, 
                           false, &rx_result);
    
    rx_result.error_percent = validate_data_integrity(tx_buf, rx_buf, config->transfer_size) / 100.0f;
    print_test_results(&tx_result, &rx_result);
    return EXIT_SUCCESS;
}

static int run_dual_mode_test(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config) {
    TestResult tx_result = {0}, rx_result = {0};
    struct timeval start, end;

    printf("\nStarting Dual Mode Test\n");
    
    // TX Phase
    gettimeofday(&start, NULL);
    for (uint32_t i = 0; i < config->cycle_count; i++) {
        if (perform_transfer(fd, tx_buf, NULL, config) < 0) {
            perror("TX transfer failed");
            return EXIT_FAILURE;
        }
    }
    gettimeofday(&end, NULL);
    calculate_transfer_stats(&start, &end, config->transfer_size * config->cycle_count, 
                           true, &tx_result);

    // RX Phase
    config->spi_mode = (config->spi_mode & ~SPI_TX_DUAL) | SPI_RX_DUAL;
    if (configure_spi_interface(fd, config) != 0) {
        return EXIT_FAILURE;
    }

    gettimeofday(&start, NULL);
    for (uint32_t i = 0; i < config->cycle_count; i++) {
        if (perform_transfer(fd, NULL, rx_buf, config) < 0) {
            perror("RX transfer failed");
            return EXIT_FAILURE;
        }
    }
    gettimeofday(&end, NULL);
    calculate_transfer_stats(&start, &end, config->transfer_size * config->cycle_count, 
                           false, &rx_result);


    rx_result.error_percent = validate_data_integrity(tx_buf, rx_buf, config->transfer_size) / 100.0f;
    print_test_results(&tx_result, &rx_result);
    return EXIT_SUCCESS;
}

static int run_quad_mode_test(int fd, uint8_t* tx_buf, uint8_t* rx_buf, SpiTestConfig* config) {
    TestResult tx_result = {0}, rx_result = {0};
    struct timeval start, end;

    printf("\nStarting Quad Mode Test\n");
    
    // TX Phase
    config->spi_mode |= SPI_TX_QUAD;
    if (configure_spi_interface(fd, config) != 0) {
        return EXIT_FAILURE;
    }

    gettimeofday(&start, NULL);
    for (uint32_t i = 0; i < config->cycle_count; i++) {
        if (perform_transfer(fd, tx_buf, NULL, config) < 0) {
            perror("TX transfer failed");
            return EXIT_FAILURE;
        }
    }
    gettimeofday(&end, NULL);
    calculate_transfer_stats(&start, &end, config->transfer_size * config->cycle_count, 
                           true, &tx_result);

    // RX Phase
    config->spi_mode = (config->spi_mode & ~SPI_TX_QUAD) | SPI_RX_QUAD;
    if (configure_spi_interface(fd, config) != 0) {
        return EXIT_FAILURE;
    }

    gettimeofday(&start, NULL);
    for (uint32_t i = 0; i < config->cycle_count; i++) {
        if (perform_transfer(fd, NULL, rx_buf, config) < 0) {
            perror("RX transfer failed");
            return EXIT_FAILURE;
        }
    }
    gettimeofday(&end, NULL);
    calculate_transfer_stats(&start, &end, config->transfer_size * config->cycle_count, 
                           false, &rx_result);

    rx_result.error_percent = validate_data_integrity(tx_buf, rx_buf, config->transfer_size) / 100.0f;
    print_test_results(&tx_result, &rx_result);
    return EXIT_SUCCESS;
}

static void show_usage(const char* prog_name) {
    char* prog_copy = strdup(prog_name);
    printf("Usage: %s [options]\n"
           "Options:\n"
           "  -d, --device <path>    SPI device (default: %s)\n"
           "  -s, --speed <hz>       Transfer speed in Hz (required)\n"
           "  -S, --size <bytes>     Transfer size per cycle (required)\n"
           "  -c, --cycles <count>   Number of test cycles (required)\n"
           "  -m, --mode <1|2|3>     Transfer mode (1=Single, 2=Dual, 3=Quad)\n"
           "  -b, --bpw <bits>       Bits per word (default: 8)\n"
           "  -D, --delay <us>       Delay after transfer in microseconds\n"
           "  -O, --cpol             Clock polarity high\n"
           "  -H, --cpha             Clock phase trailing edge\n"
           "  -L, --lsb              Least significant bit first\n"
           "  -C, --cs-high          Chip select active high\n"
           "  -3, --3wire            3-wire mode\n"
           "  -v, --version          Show version\n"
           "  -h, --help             Show this help\n"
           "\nExample:\n"
           "  %s -d /dev/spidev0.0 -s 150000000 -S 4096 -c 100 -m 1\n",
           basename(prog_copy), DEFAULT_DEVICE, basename(prog_copy));
    free(prog_copy);
}