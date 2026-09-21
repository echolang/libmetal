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

uint64_t mtl_device_max_tessellation_factor(void *device)
{
    id<MTLDevice> d = mtl_id(device);
    if ([d supportsFamily:MTLGPUFamilyApple4]) {
        return 64;
    }

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    if ([d supportsFamily:MTLGPUFamilyMac2]) {
        return 64;
    }
#endif

    return 16;
}

uint64_t mtl_device_current_allocated(void *device)
{
    id<MTLDevice> d = mtl_id(device);
    return (uint64_t)d.currentAllocatedSize;
}

uint64_t mtl_device_working_set(void *device)
{
    id<MTLDevice> d = mtl_id(device);
    return (uint64_t)d.recommendedMaxWorkingSetSize;
}

int32_t mtl_device_has_unified(void *device)
{
    id<MTLDevice> d = mtl_id(device);
    return d.hasUnifiedMemory ? 1 : 0;
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

void *mtl_device_new_shared_event(void *device)
{
    id<MTLDevice> d = mtl_id(device);
    return mtl_retain_id([d newSharedEvent]);
}

uint64_t mtl_shared_event_value(void *event)
{
    id<MTLSharedEvent> e = mtl_id(event);
    return e.signaledValue;
}

void mtl_shared_event_set_value(void *event, uint64_t value)
{
    id<MTLSharedEvent> e = mtl_id(event);
    e.signaledValue = value;
}

int32_t mtl_shared_event_wait(void *event, uint64_t value, uint64_t timeout_ms)
{
    id<MTLSharedEvent> e = mtl_id(event);
    return [e waitUntilSignaledValue:value timeoutMS:timeout_ms] ? 1 : 0;
}

int32_t mtl_device_supports_counter_sampling(void *device, uint32_t point)
{
    id<MTLDevice> d = mtl_id(device);

    if (@available(macOS 11.0, iOS 14.0, tvOS 14.0, *)) {
        return [d supportsCounterSampling:(MTLCounterSamplingPoint)point] ? 1 : 0;
    }

    return 0;
}

static id<MTLCounterSet> mtl_timestamp_set(id<MTLDevice> d)
{
    for (id<MTLCounterSet> set in d.counterSets) {
        if ([set.name isEqualToString:MTLCommonCounterSetTimestamp]) {
            return set;
        }
    }

    return nil;
}

int32_t mtl_device_has_timestamp_counters(void *device)
{
    return mtl_timestamp_set(mtl_id(device)) != nil ? 1 : 0;
}

void *mtl_device_new_counter_sample_buffer(
    void *device,
    uint64_t count,
    uint32_t storage_mode,
    const char *label,
    char *err,
    size_t err_cap)
{
    id<MTLDevice> d = mtl_id(device);
    id<MTLCounterSet> set = mtl_timestamp_set(d);

    if (set == nil) {
        mtl_copy_nsstring(@"device has no timestamp counter set", err, err_cap);
        return NULL;
    }

    MTLCounterSampleBufferDescriptor *desc = [[MTLCounterSampleBufferDescriptor alloc] init];
    desc.counterSet = set;
    desc.sampleCount = (NSUInteger)count;
    desc.storageMode = (MTLStorageMode)storage_mode;

    if (label != NULL) {
        desc.label = [NSString stringWithUTF8String:label];
    }

    NSError *e = nil;
    id<MTLCounterSampleBuffer> buf = [d newCounterSampleBufferWithDescriptor:desc error:&e];

    if (buf == nil) {
        mtl_copy_error(e, err, err_cap);
        return NULL;
    }

    return mtl_retain_id(buf);
}

uint64_t mtl_counter_sample_buffer_count(void *buf)
{
    id<MTLCounterSampleBuffer> b = mtl_id(buf);
    return (uint64_t)b.sampleCount;
}

uint64_t mtl_counter_sample_buffer_resolve(void *buf, uint64_t first, uint64_t count, uint64_t *out)
{
    id<MTLCounterSampleBuffer> b = mtl_id(buf);
    NSData *data = [b resolveCounterRange:NSMakeRange((NSUInteger)first, (NSUInteger)count)];

    if (data == nil || out == NULL) {
        return 0;
    }

    const MTLCounterResultTimestamp *r = (const MTLCounterResultTimestamp *)data.bytes;
    uint64_t n = (uint64_t)(data.length / sizeof(MTLCounterResultTimestamp));
    uint64_t i;

    if (n > count) {
        n = count;
    }

    for (i = 0; i < n; i++) {
        out[i] = r[i].timestamp;
    }

    return n;
}

uint64_t mtl_counter_error_value(void)
{
    return (uint64_t)MTLCounterErrorValue;
}

uint64_t mtl_counter_dont_sample(void)
{
    return (uint64_t)MTLCounterDontSample;
}

void mtl_device_sample_timestamps(void *device, uint64_t *cpu_ns, uint64_t *gpu_ticks)
{
    id<MTLDevice> d = mtl_id(device);
    MTLTimestamp c = 0;
    MTLTimestamp g = 0;
    [d sampleTimestamps:&c gpuTimestamp:&g];

    if (cpu_ns != NULL) {
        *cpu_ns = (uint64_t)c;
    }

    if (gpu_ticks != NULL) {
        *gpu_ticks = (uint64_t)g;
    }
}
