#include "camera_protocol.h"
#include <stdio.h>
#define CHECK(x) do { if(!(x)){fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x);return 1;} } while(0)
int main(void)
{
    uint8_t fixture[32];for(unsigned i=0;i<32;i++)fixture[i]=(uint8_t)i;
    CHECK(camera_checksum(fixture,sizeof fixture)==UINT32_C(0x21f8d40d));
    CHECK(camera_chunk(0x100ff0,512000)==16);
    CHECK(camera_chunk(0x101000,512000)==4096);
    CHECK(camera_chunk(0x101000,256)==256);
    CHECK(camera_chunk(3,16)==0);CHECK(camera_chunk(16,17)==0);
    CHECK(camera_chunk(0xfffffff0u,32)==0);CHECK(camera_chunk(0xfffffff0u,16)==16);
    CHECK(camera_command(16)==0x01000003);CHECK(camera_command(4096)==0x010003ff);
    CHECK(camera_command(4100)==0);CHECK(camera_command(0)==0);
    uint32_t offset=0,n=0;
    while(offset<512000){uint32_t size=camera_chunk(0x100000+offset,512000-offset);
        CHECK(size!=0 && size<=4096);CHECK(((offset&4095u)+size)<=4096);offset+=size;n++;}
    CHECK(offset==512000 && n==125);
    puts("PASS ARM protocol: RTL checksum fixture, 4 KiB splits, alignment, 32-bit bounds, 125 descriptors per 640x400 frame");
    return 0;
}
