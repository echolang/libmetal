#import "internal.h"

void *mtl_device_new_buffer(void *device, uint64_t length, uint32_t options)
{
    id<MTLDevice> d = mtl_id(device);
    id<MTLBuffer> b = [d newBufferWithLength:(NSUInteger)length
                                     options:(MTLResourceOptions)options];
    return mtl_retain_id(b);
}

void *mtl_device_new_buffer_bytes(void *device, const void *bytes, uint64_t length, uint32_t options)
{
    id<MTLDevice> d = mtl_id(device);
    id<MTLBuffer> b = [d newBufferWithBytes:bytes
                                     length:(NSUInteger)length
                                    options:(MTLResourceOptions)options];
    return mtl_retain_id(b);
}

void *mtl_device_new_texture(void *device, const mtl_texture_desc *desc)
{
    if (desc == NULL) {
        return NULL;
    }

    MTLTextureDescriptor *td = [[MTLTextureDescriptor alloc] init];
    td.textureType = (MTLTextureType)desc->texture_type;
    td.pixelFormat = (MTLPixelFormat)desc->pixel_format;
    td.width = (NSUInteger)desc->width;
    td.height = (NSUInteger)desc->height;
    td.depth = (NSUInteger)desc->depth;
    td.mipmapLevelCount = (NSUInteger)desc->mipmap_level_count;
    td.sampleCount = (NSUInteger)desc->sample_count;
    td.arrayLength = (NSUInteger)desc->array_length;
    td.usage = (MTLTextureUsage)desc->usage;
    td.storageMode = (MTLStorageMode)desc->storage_mode;

    id<MTLDevice> d = mtl_id(device);
    return mtl_retain_id([d newTextureWithDescriptor:td]);
}

void *mtl_device_new_sampler(void *device, const mtl_sampler_desc *desc)
{
    if (desc == NULL) {
        return NULL;
    }

    MTLSamplerDescriptor *sd = [[MTLSamplerDescriptor alloc] init];
    sd.minFilter = (MTLSamplerMinMagFilter)desc->min_filter;
    sd.magFilter = (MTLSamplerMinMagFilter)desc->mag_filter;
    sd.mipFilter = (MTLSamplerMipFilter)desc->mip_filter;
    sd.sAddressMode = (MTLSamplerAddressMode)desc->s_address;
    sd.tAddressMode = (MTLSamplerAddressMode)desc->t_address;
    sd.rAddressMode = (MTLSamplerAddressMode)desc->r_address;
    sd.normalizedCoordinates = desc->normalized != 0;

    id<MTLDevice> d = mtl_id(device);
    return mtl_retain_id([d newSamplerStateWithDescriptor:sd]);
}

uint64_t mtl_buffer_length(void *buffer)
{
    id<MTLBuffer> b = mtl_id(buffer);
    return (uint64_t)b.length;
}

void *mtl_buffer_contents(void *buffer)
{
    id<MTLBuffer> b = mtl_id(buffer);
    return b.contents;
}

void mtl_texture_replace(
    void *texture,
    uint64_t ox,
    uint64_t oy,
    uint64_t oz,
    uint64_t width,
    uint64_t height,
    uint64_t depth,
    uint32_t mip,
    const void *bytes,
    uint64_t bytes_per_row)
{
    id<MTLTexture> t = mtl_id(texture);
    MTLRegion r = {
        { (NSUInteger)ox, (NSUInteger)oy, (NSUInteger)oz },
        { (NSUInteger)width, (NSUInteger)height, (NSUInteger)depth }
    };
    [t replaceRegion:r
         mipmapLevel:(NSUInteger)mip
           withBytes:bytes
         bytesPerRow:(NSUInteger)bytes_per_row];
}

uint64_t mtl_texture_width(void *texture)
{
    id<MTLTexture> t = mtl_id(texture);
    return (uint64_t)t.width;
}

uint64_t mtl_texture_height(void *texture)
{
    id<MTLTexture> t = mtl_id(texture);
    return (uint64_t)t.height;
}
