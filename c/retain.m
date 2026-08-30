#import "mtl.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <string.h>

void mtl_retain(void *obj)
{
    if (obj) {
        CFRetain(obj);
    }
}

void mtl_release(void *obj)
{
    if (obj) {
        CFRelease(obj);
    }
}

void mtl_copy_nsstring(NSString *s, char *buf, size_t cap)
{
    if (buf == NULL || cap == 0) {
        return;
    }

    buf[0] = '\0';

    if (s == nil) {
        return;
    }

    const char *utf8 = [s UTF8String];

    if (utf8 == NULL) {
        return;
    }

    size_t n = strlen(utf8);

    if (n >= cap) {
        n = cap - 1;
    }

    memcpy(buf, utf8, n);
    buf[n] = '\0';
}

void mtl_copy_error(NSError *err, char *buf, size_t cap)
{
    if (err == nil) {
        mtl_copy_nsstring(nil, buf, cap);
        return;
    }

    mtl_copy_nsstring(err.localizedDescription, buf, cap);
}

id mtl_id(void *p)
{
    return p ? (__bridge id)p : nil;
}

void *mtl_retain_id(id obj)
{
    return obj ? (__bridge_retained void *)obj : NULL;
}
