#ifndef TEGzip_h
#define TEGzip_h

#include <stddef.h>
#include <stdint.h>

int te_gunzip(const uint8_t *src, size_t src_len, uint8_t **dst, size_t *dst_len);

#endif
