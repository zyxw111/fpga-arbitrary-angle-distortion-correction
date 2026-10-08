#include <stdio.h>
#include <stdlib.h>
#include <linux/i2c-dev.h> 
#include <fcntl.h>         
#include <unistd.h>        
#include <sys/ioctl.h>     
#include <string.h>        

#define I2C_DEVICE "/dev/i2c-0" 
#define I2C_ADDR 0x66          

void print_help() {
    printf("Usage: i2c_test [options]\n");
    printf("Options:\n");
    printf("  -help              Show this help message\n");
    printf("  -read <reg>        Read value from register <reg> ( -read 0X00)\n");
    printf("  -write <reg> <val> Write value <val> to register <reg> (-write 0X00 0X40)\n");
    printf("  -led <state>       Control LED state (ON: turn on, OFF: turn off)\n");
}

int i2c_read(int fd, unsigned char reg) {
    unsigned char buf[1];
    if (write(fd, &reg, 1) != 1) {
        perror("Failed to write register address");
        return -1;
    }
    if (read(fd, buf, 1) != 1) {
        perror("Failed to read register value");
        return -1;
    }
    return buf[0];
}

int i2c_write(int fd, unsigned char reg, unsigned char val) {
    unsigned char buf[2] = {reg, val};
    if (write(fd, buf, 2) != 2) {
        perror("Failed to write to register");
        return -1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_help();
        return 0;
    }

    if (strcmp(argv[1], "-help") == 0) {
        print_help();
        return 0;
    }

    int fd = open(I2C_DEVICE, O_RDWR);
    if (fd < 0) {
        perror("Failed to open I2C device");
        return 1;
    }

    if (ioctl(fd, I2C_SLAVE, I2C_ADDR) < 0) {
        perror("Failed to set I2C slave address");
        close(fd);
        return 1;
    }

    if (strcmp(argv[1], "-read") == 0 && argc == 3) {
        unsigned char reg = strtol(argv[2], NULL, 16);
        int val = i2c_read(fd, reg);
        if (val >= 0) {
            printf("Register 0x%02X: 0x%02X\n", reg, val);
        }
    } else if (strcmp(argv[1], "-write") == 0 && argc == 4) {
        unsigned char reg = strtol(argv[2], NULL, 16);
        unsigned char val = strtol(argv[3], NULL, 16);
        if (i2c_write(fd, reg, val) == 0) {
            printf("Wrote 0x%02X to register 0x%02X\n", val, reg);
        }
    } else if (strcmp(argv[1], "-led") == 0 && argc == 3) {
        unsigned char val;
        if (strcmp(argv[2], "ON") == 0) {
            val = 0x01; 
        } else if (strcmp(argv[2], "OFF") == 0) {
            val = 0x00; 
        } else {
            printf("Invalid LED state. Use ON or OFF.\n");
            close(fd);
            return 1;
        }
        if (i2c_write(fd, 0x01, val) == 0) {
            printf("LED state set to %s\n", argv[2]);
        }
    } else {
        print_help();
    }

    close(fd);
    return 0;
}