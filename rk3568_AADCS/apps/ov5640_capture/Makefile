CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Werror
BUILD := build
TARGET := $(BUILD)/ov5640-capture

.PHONY: all test clean
all: $(TARGET)
$(BUILD):
	mkdir -p $(BUILD)
$(TARGET): ov5640_capture.c camera_protocol.h | $(BUILD)
	$(CC) $(CFLAGS) ov5640_capture.c -o $@
test: | $(BUILD)
	$(CC) $(CFLAGS) test_protocol.c -o $(BUILD)/test-protocol
	./$(BUILD)/test-protocol
clean:
	rm -f $(BUILD)/ov5640-capture $(BUILD)/test-protocol
