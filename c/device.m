#import "internal.h"

void *mtl_device_default(void)
{
    return mtl_retain_id(MTLCreateSystemDefaultDevice());
}

uint64_t mtl_device_count(void)
{
#if TARGET_OS_OSX
    return (uint64_t)MTLCopyAllDevices().count;
#else
    return MTLCreateSystemDefaultDevice() != nil ? 1 : 0;
#endif
}

void *mtl_device_at(uint64_t i)
{
#if TARGET_OS_OSX
    NSArray<id<MTLDevice>> *all = MTLCopyAllDevices();

    if (i >= (uint64_t)all.count) {
        return NULL;
    }

    return mtl_retain_id(all[i]);
#else
    if (i != 0) {
        return NULL;
    }

    return mtl_retain_id(MTLCreateSystemDefaultDevice());
#endif
}

void mtl_device_name(void *device, char *buf, size_t cap)
{
    id<MTLDevice> d = mtl_id(device);
    mtl_copy_nsstring(d.name, buf, cap);
}

void *mtl_device_new_queue(void *device, const char *label)
{
    id<MTLDevice> d = mtl_id(device);
    id<MTLCommandQueue> q = [d newCommandQueue];

    if (q != nil && label != NULL) {
        q.label = [NSString stringWithUTF8String:label];
    }

    return mtl_retain_id(q);
}
