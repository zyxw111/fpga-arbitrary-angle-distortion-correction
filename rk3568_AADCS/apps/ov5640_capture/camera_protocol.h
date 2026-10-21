#ifndef AADCS_CAMERA_PROTOCOL_H
#define AADCS_CAMERA_PROTOCOL_H
#include <stddef.h>
#include <stdint.h>

#define CAMERA_MAGIC UINT32_C(0x43414d32)
#define CAMERA_VERSION UINT32_C(0x00020000)
#define CAMERA_FRAME_READY 1u
#define CAMERA_BUSY 2u
#define CAMERA_ENGINE_ERROR 4u
#define CAMERA_CONFIG_READY 8u
#define CAMERA_CONFIG_ERROR 16u

static inline uint32_t camera_rotl(uint32_t v, unsigned n)
{
    return (v << n) | (v >> (32u-n));
}
static inline uint32_t camera_le32(const volatile uint8_t *p)
{
    return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24;
}
/* Same rolling diagnostic checksum as camera_frame.v, not a cryptographic CRC. */
static inline uint32_t camera_checksum(const volatile uint8_t *p, size_t bytes)
{
    uint32_t h=0;
    for(size_t i=0;i<bytes;i+=16){
        h=camera_rotl(h,5) ^ camera_le32(p+i) ^ camera_rotl(camera_le32(p+i+4),1)
          ^ camera_rotl(camera_le32(p+i+8),3) ^ camera_rotl(camera_le32(p+i+12),7);
    }
    return h;
}
static inline uint32_t camera_chunk(uint32_t address, uint32_t remaining)
{
    if((address&15u) || !remaining || (remaining&15u) ||
       (uint64_t)address+remaining>UINT64_C(0x100000000))return 0;
    uint32_t room=4096u-(address&4095u);
    return remaining<room?remaining:room;
}
static inline uint32_t camera_command(uint32_t bytes)
{
    if(!bytes || bytes>4096 || (bytes&15u))return 0;
    return UINT32_C(0x01000000) | (bytes/4u-1u);
}
#endif
