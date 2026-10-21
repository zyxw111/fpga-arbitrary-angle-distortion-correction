#define _POSIX_C_SOURCE 200809L
#include "camera_protocol.h"
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <inttypes.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define DMA_SETUP 0x01000000u
#define DMA_SHUTDOWN 0x04000000u
struct dma_config {uint32_t src_phys_addr,dst_phys_addr,direction,chunk_size,total_size;};
_Static_assert(sizeof(struct dma_config)==20,"vendor DMA ioctl ABI");
static volatile sig_atomic_t stopping;
static void stop_capture(int sig){(void)sig;stopping=1;}
static uint64_t now_ms(void)
{
    struct timespec t;if(clock_gettime(CLOCK_MONOTONIC,&t)){perror("clock_gettime");exit(2);}
    return (uint64_t)t.tv_sec*1000u+(uint64_t)t.tv_nsec/1000000u;
}
static void pause_us(long us){struct timespec t={us/1000000,(us%1000000)*1000};nanosleep(&t,NULL);}
static uint32_t bar_read(volatile uint8_t *bar,unsigned off)
{
    uint32_t v=*(volatile uint32_t *)(bar+off);__sync_synchronize();return v;
}
static void bar_write(volatile uint8_t *bar,unsigned off,uint32_t value)
{
    __sync_synchronize();*(volatile uint32_t *)(bar+off)=value;__sync_synchronize();
}
static int fail_status(volatile uint8_t *bar)
{
    uint32_t flags=bar_read(bar,8);
    if(flags&(CAMERA_ENGINE_ERROR|CAMERA_CONFIG_ERROR)){
        fprintf(stderr,"FPGA error: flags=%08" PRIx32 " chip=%04" PRIx32
            " config/host=%08" PRIx32 " init_index=%" PRIu32 " pipeline=%08" PRIx32 "\n",
            flags,bar_read(bar,0x30),bar_read(bar,0x34),bar_read(bar,0x38),bar_read(bar,0x3c));
        return -1;
    }
    return 0;
}
static int dump_raw(const char *path,const void *data,size_t size)
{
    FILE *f=fopen(path,"wb");if(!f){perror(path);return -1;}
    int rc=fwrite(data,1,size,f)==size?0:-1;if(fclose(f))rc=-1;return rc;
}
static int dump_ppm(const char *path,const uint8_t *data,unsigned width,unsigned height)
{
    FILE *f=fopen(path,"wb");if(!f){perror(path);return -1;}
    if(fprintf(f,"P6\n%u %u\n255\n",width,height)<0){fclose(f);return -1;}
    for(size_t i=0;i<(size_t)width*height;i++){
        unsigned pixel=data[2*i]|(unsigned)data[2*i+1]<<8;
        uint8_t rgb[3]={(uint8_t)(((pixel>>11)&31)*255/31),
                        (uint8_t)(((pixel>>5)&63)*255/63),(uint8_t)((pixel&31)*255/31)};
        if(fwrite(rgb,1,3,f)!=3){fclose(f);return -1;}
    }
    return fclose(f)?-1:0;
}
static void usage(const char *name)
{
    printf("%s [--pci /sys/bus/pci/devices/BDF] [--dma /dev/pcie_dma_memcpy]\n"
           "  [--frames N] [--timeout-ms N] [--output last.rgb565] [--ppm last.ppm]\n"
           "Use the CAM2 FPGA firmware. Default: 30 frames, timeout 5000 ms.\n"
           "PCIe writes go to the coherent RK3568 DDR buffer allocated by the driver.\n",name);
}
int main(int argc,char **argv)
{
    const char *pci="/sys/bus/pci/devices/0002:21:00.0",*dma="/dev/pcie_dma_memcpy",*raw=NULL,*ppm=NULL;
    unsigned frames=30,timeout=5000;
    static const struct option options[]={{"pci",1,0,'b'},{"dma",1,0,'d'},{"frames",1,0,'n'},
        {"timeout-ms",1,0,'t'},{"output",1,0,'o'},{"ppm",1,0,'p'},{"help",0,0,'h'},{0,0,0,0}};
    int opt;while((opt=getopt_long(argc,argv,"b:d:n:t:o:p:h",options,NULL))!=-1){
        if(opt=='b')pci=optarg;else if(opt=='d')dma=optarg;else if(opt=='o')raw=optarg;
        else if(opt=='p')ppm=optarg;else if(opt=='h'){usage(argv[0]);return 0;}
        else if(opt=='n' || opt=='t'){
            char *end;errno=0;unsigned long value=strtoul(optarg,&end,10);
            if(errno || !*optarg || *end || value>1000000 || (opt=='t' && !value)){usage(argv[0]);return 2;}
            if(opt=='n')frames=(unsigned)value;else timeout=(unsigned)value;
        }else{usage(argv[0]);return 2;}
    }
    if(optind!=argc){usage(argv[0]);return 2;}
    signal(SIGINT,stop_capture);signal(SIGTERM,stop_capture);
    int result=2,fd0=-1,fd1=-1,fd_dma=-1,allocated=0,inflight=0;
    volatile uint8_t *bar0=MAP_FAILED,*bar1=MAP_FAILED;
    uint8_t *buffer=MAP_FAILED;uint32_t bytes=0,bus=0,completed=0,last_frame=UINT32_MAX;
    unsigned received=0;uint64_t started=now_ms();char path[4096];
    if(snprintf(path,sizeof path,"%s/resource0",pci)>=(int)sizeof path)goto cleanup;
    fd0=open(path,O_RDONLY|O_CLOEXEC);if(fd0<0){perror(path);goto cleanup;}
    bar0=mmap(NULL,4096,PROT_READ,MAP_SHARED,fd0,0);if(bar0==MAP_FAILED){perror("BAR0 mmap");goto cleanup;}
    if(bar_read(bar0,0)!=CAMERA_MAGIC || bar_read(bar0,4)!=CAMERA_VERSION){
        fprintf(stderr,"Wrong FPGA firmware: magic=%08" PRIx32 " version=%08" PRIx32 " (need CAM2/00020000)\n",bar_read(bar0,0),bar_read(bar0,4));goto cleanup;
    }
    unsigned width=bar_read(bar0,16),height=bar_read(bar0,20),stride=bar_read(bar0,24);bytes=bar_read(bar0,28);
    if(width!=640 || height!=400 || stride!=1280 || bytes!=512000){fprintf(stderr,"Unexpected FPGA geometry\n");goto cleanup;}
    if(snprintf(path,sizeof path,"%s/resource1",pci)>=(int)sizeof path)goto cleanup;
    fd1=open(path,O_RDWR|O_CLOEXEC);if(fd1<0){perror(path);goto cleanup;}
    bar1=mmap(NULL,4096,PROT_READ|PROT_WRITE,MAP_SHARED,fd1,0);if(bar1==MAP_FAILED){perror("BAR1 mmap");goto cleanup;}
    fd_dma=open(dma,O_RDWR|O_CLOEXEC);if(fd_dma<0){perror(dma);goto cleanup;}
    if(flock(fd_dma,LOCK_EX|LOCK_NB)){perror("DMA device already in use");goto cleanup;}
    struct dma_config cfg={0,0,1,bytes,bytes};
    errno=0;long allocation=ioctl(fd_dma,DMA_SETUP,&cfg);
    if(allocation==-1){perror("DMA_SETUP");goto cleanup;}
    bus=(uint32_t)allocation;allocated=1;
    if(!bus || (bus&4095u) || (uint64_t)bus+bytes>UINT64_C(0x100000000)){
        fprintf(stderr,"Invalid driver DMA allocation %08" PRIx32 "\n",bus);goto cleanup;
    }
    buffer=mmap(NULL,bytes,PROT_READ|PROT_WRITE,MAP_SHARED,fd_dma,0);if(buffer==MAP_FAILED){perror("coherent DMA mmap");goto cleanup;}
    printf("CAM2 %ux%u RGB565: RK3568 DDR DMA bus=%08" PRIx32 " bytes=%" PRIu32 "\n",width,height,bus,bytes);
    completed=bar_read(bar0,12);
    while(!stopping && (!frames || received<frames)){
        uint64_t deadline=now_ms()+timeout;uint32_t id,expected;
        while(1){
            if(fail_status(bar0))goto cleanup;
            uint32_t flags=bar_read(bar0,8);id=bar_read(bar0,32);
            if((flags&(CAMERA_FRAME_READY|CAMERA_BUSY))==CAMERA_FRAME_READY && id!=last_frame)break;
            if(stopping)goto finish_capture;
            if(now_ms()>=deadline){fprintf(stderr,"Camera ready timeout; chip=%04" PRIx32 " init=%" PRIu32 " good=%" PRIu32 " dropped=%" PRIu32 "\n",
                bar_read(bar0,0x30),bar_read(bar0,0x38),id,bar_read(bar0,36));goto cleanup;}
            pause_us(100);
        }
        if(bar_read(bar0,40)!=0){fprintf(stderr,"FPGA cursor is not at frame start; reset KEY0 before capture\n");goto cleanup;}
        completed=bar_read(bar0,12);
        expected=bar_read(bar0,44);
        uint32_t seed=UINT32_C(0x9e3779b9)^id;
        for(uint32_t i=0;i<bytes;i++){seed=seed*1664525u+1013904223u;buffer[i]=(uint8_t)(seed>>24);}
        __sync_synchronize();
        for(uint32_t offset=0;offset<bytes;){
            uint32_t amount=camera_chunk(bus+offset,bytes-offset);if(!amount)goto cleanup;
            bar_write(bar1,0x110,bus+offset);bar_write(bar1,0x120,0);
            inflight=1;bar_write(bar1,0x100,camera_command(amount));
            completed++;deadline=now_ms()+timeout;
            while(bar_read(bar0,12)!=completed){
                if(fail_status(bar0))goto cleanup;
                if(now_ms()>=deadline){fprintf(stderr,"DMA timeout at byte %" PRIu32 "\n",offset);goto cleanup;}
                pause_us(20);
            }
            inflight=0;offset+=amount;
        }
        __sync_synchronize();deadline=now_ms()+timeout;
        while(camera_checksum(buffer,bytes)!=expected){
            if(now_ms()>=deadline){fprintf(stderr,"Payload checksum/visibility mismatch (driver must use coherent DMA mapping)\n");goto cleanup;}
            __sync_synchronize();pause_us(50);
        }
        received++;last_frame=id;
        printf("frame=%u sensor_capture=%" PRIu32 " checksum=%08" PRIx32 " average=%.2f fps dropped=%" PRIu32 "\n",
            received,id,expected,received*1000.0/(double)(now_ms()-started+1),bar_read(bar0,36));
        fflush(stdout);
    }
finish_capture:
    if(received && raw && dump_raw(raw,buffer,bytes))goto cleanup;
    if(received && ppm && dump_ppm(ppm,buffer,width,height))goto cleanup;
    result=0;
cleanup:
    /* A timed-out descriptor may still write. Do not return its DMA allocation
       to the kernel pool through SHUTDOWN until the endpoint has been reset. */
    if(inflight)fprintf(stderr,"DMA still pending: allocation retained (no SHUTDOWN). Reset FPGA and reboot ARM before retry.\n");
    if(buffer!=MAP_FAILED)munmap(buffer,bytes);
    if(allocated && !inflight && ioctl(fd_dma,DMA_SHUTDOWN,0)<0)perror("DMA_SHUTDOWN");
    if(bar1!=MAP_FAILED)munmap((void *)bar1,4096);
    if(bar0!=MAP_FAILED)munmap((void *)bar0,4096);
    if(fd_dma>=0)close(fd_dma);
    if(fd1>=0)close(fd1);
    if(fd0>=0)close(fd0);
    return result;
}
