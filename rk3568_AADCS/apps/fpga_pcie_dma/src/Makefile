CC ?= aarch64-buildroot-linux-gnu-gcc
INCLUDE +=
CFLAGS  += -g -Wall -O2 $(INCLUDE)
LIBS    +=
LDFLAGS :=
CXXFLAGS:= $(CFLAGS)
SOURCE  := $(wildcard *.c) $(wildcard *.cpp)
OBJS    := $(patsubst %.c,%.o,$(patsubst %.cpp,%.o,$(SOURCE)))
TARGET  := dma_memcpy_demo

.PHONY : everything objs clean distclean rebuild

all : $(TARGET)

objs : $(OBJS)

rebuild: distclean all

clean :
	rm -rf *~
	rm -rf *.o

distclean : clean
	rm -rf $(TARGET)

$(TARGET) : $(OBJS)
	$(CC) $(CXXFLAGS) -o $@ $(OBJS) $(LDFLAGS) $(LIBS)
