#import "internal.h"

#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/CATransaction.h>
#import <objc/message.h>
#import <objc/runtime.h>

static CAMetalLayer *mtl_new_layer(id<MTLDevice> device, uint64_t width, uint64_t height, uint32_t pixel_format)
{
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.pixelFormat = (MTLPixelFormat)pixel_format;
    layer.framebufferOnly = YES;
    // default opaque is NO; WindowServer then composites and vsyncs even with displaySyncEnabled off
    layer.opaque = YES;
    layer.drawableSize = CGSizeMake((CGFloat)width, (CGFloat)height);
    return layer;
}

void *mtl_layer_create(void *device, uint64_t width, uint64_t height, uint32_t pixel_format)
{
    return mtl_retain_id(mtl_new_layer(mtl_id(device), width, height, pixel_format));
}

void *mtl_layer_from_ptr(void *layer)
{
    if (layer == NULL) {
        return NULL;
    }

    mtl_retain(layer);
    return layer;
}

void *mtl_layer_attach_view(void *device, void *view, uint32_t pixel_format)
{
    id host = mtl_id(view);

    if (host == nil) {
        return NULL;
    }

#if TARGET_OS_OSX
    CAMetalLayer *layer = mtl_new_layer(mtl_id(device), 1, 1, pixel_format);
    SEL setWantsLayer = sel_registerName("setWantsLayer:");
    SEL setLayer = sel_registerName("setLayer:");
    // wantsLayer first so AppKit does not wrap the metal layer in a backing CALayer
    ((void (*)(id, SEL, BOOL))objc_msgSend)(host, setWantsLayer, YES);
    ((void (*)(id, SEL, id))objc_msgSend)(host, setLayer, layer);
    return mtl_retain_id(layer);
#else
    SEL layerSel = sel_registerName("layer");
    id hostLayer = ((id (*)(id, SEL))objc_msgSend)(host, layerSel);

    if (hostLayer == nil || ![hostLayer isKindOfClass:[CAMetalLayer class]]) {
        return NULL;
    }

    CAMetalLayer *existing = (CAMetalLayer *)hostLayer;
    existing.device = mtl_id(device);
    existing.pixelFormat = (MTLPixelFormat)pixel_format;
    existing.opaque = YES;
    return mtl_retain_id(existing);
#endif
}

void mtl_layer_set_device(void *layer, void *device)
{
    CAMetalLayer *l = mtl_id(layer);
    l.device = mtl_id(device);
}

void mtl_layer_set_pixel_format(void *layer, uint32_t format)
{
    CAMetalLayer *l = mtl_id(layer);
    l.pixelFormat = (MTLPixelFormat)format;
}

void mtl_layer_set_drawable_size(void *layer, uint64_t width, uint64_t height)
{
    CAMetalLayer *l = mtl_id(layer);
    l.drawableSize = CGSizeMake((CGFloat)width, (CGFloat)height);
}

void mtl_layer_get_drawable_size(void *layer, uint64_t *width, uint64_t *height)
{
    CAMetalLayer *l = mtl_id(layer);
    CGSize s = l.drawableSize;

    if (width != NULL) {
        *width = (uint64_t)s.width;
    }

    if (height != NULL) {
        *height = (uint64_t)s.height;
    }
}

void mtl_layer_set_contents_scale(void *layer, double scale)
{
    CAMetalLayer *l = mtl_id(layer);
    l.contentsScale = (CGFloat)scale;
}

double mtl_layer_contents_scale(void *layer)
{
    CAMetalLayer *l = mtl_id(layer);
    return (double)l.contentsScale;
}

void mtl_layer_set_framebuffer_only(void *layer, int32_t only)
{
    CAMetalLayer *l = mtl_id(layer);
    l.framebufferOnly = only != 0;
}

void mtl_layer_set_opaque(void *layer, int32_t opaque)
{
    CAMetalLayer *l = mtl_id(layer);
    l.opaque = opaque != 0;
}

void mtl_layer_set_display_sync(void *layer, int32_t enabled)
{
    CAMetalLayer *l = mtl_id(layer);
#if TARGET_OS_OSX
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    l.displaySyncEnabled = enabled != 0;
    [CATransaction commit];
#else
    (void)l;
    (void)enabled;
#endif
}

int32_t mtl_layer_display_sync(void *layer)
{
#if TARGET_OS_OSX
    CAMetalLayer *l = mtl_id(layer);
    return l.displaySyncEnabled ? 1 : 0;
#else
    (void)layer;
    return 1;
#endif
}

void mtl_layer_set_maximum_drawable_count(void *layer, uint32_t count)
{
    CAMetalLayer *l = mtl_id(layer);
    if (count < 2) {
        count = 2;
    }
    if (count > 3) {
        count = 3;
    }
    l.maximumDrawableCount = count;
}

void *mtl_layer_next_drawable(void *layer)
{
    CAMetalLayer *l = mtl_id(layer);
    return mtl_retain_id([l nextDrawable]);
}

void *mtl_drawable_texture(void *drawable)
{
    id<CAMetalDrawable> d = mtl_id(drawable);
    id<MTLTexture> t = d.texture;
    return mtl_retain_id(t);
}
