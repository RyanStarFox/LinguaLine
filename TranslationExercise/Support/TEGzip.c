#include "TEGzip.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

int te_gunzip(const uint8_t *src, size_t src_len, uint8_t **dst, size_t *dst_len) {
    if (src == NULL || dst == NULL || dst_len == NULL || src_len < 2) {
        return 1;
    }
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit2(&stream, 16 + MAX_WBITS) != Z_OK) {
        return 2;
    }
    size_t capacity = src_len * 8;
    if (capacity < (1 << 20)) {
        capacity = 1 << 20;
    }
    uint8_t *buffer = malloc(capacity);
    if (buffer == NULL) {
        inflateEnd(&stream);
        return 3;
    }
    stream.next_in = (Bytef *)src;
    stream.avail_in = (uInt)src_len;
    size_t used = 0;
    int status = Z_OK;
    while (status != Z_STREAM_END) {
        if (used + 65536 > capacity) {
            size_t grown = capacity * 2;
            uint8_t *next = realloc(buffer, grown);
            if (next == NULL) {
                free(buffer);
                inflateEnd(&stream);
                return 3;
            }
            buffer = next;
            capacity = grown;
        }
        stream.next_out = buffer + used;
        stream.avail_out = (uInt)(capacity - used);
        status = inflate(&stream, Z_NO_FLUSH);
        used = (size_t)(stream.next_out - buffer);
        if (status != Z_OK && status != Z_STREAM_END) {
            free(buffer);
            inflateEnd(&stream);
            return 4;
        }
    }
    inflateEnd(&stream);
    *dst = buffer;
    *dst_len = used;
    return 0;
}
