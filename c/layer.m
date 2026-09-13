#import "internal.h"

#import <QuartzCore/CAMetalLayer.h>
#import <objc/message.h>
#import <objc/runtime.h>

static CAMetalLayer *mtl_new_layer(id<MTLDevice> device, uint64_t width, uint64_t height, uint32_t pixel_format)
{
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.pixelFormat = (MTLPixelFormat)pixel_format;
    layer.framebufferOnly = YES;
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

static id mtl_view_from_handle(void *handle)
{
    id obj = mtl_id(handle);

    if (obj == nil) {
        return nil;
    }

    SEL contentView = sel_registerName("contentView");

    if ([obj respondsToSelector:contentView]) {
        return ((id (*)(id, SEL))objc_msgSend)(obj, contentView);
    }

    return obj;
}

void *mtl_layer_attach_view(void *device, void *view, uint32_t pixel_format)
{
    id host = mtl_view_from_handle(view);

    if (host == nil) {
        return NULL;
    }

    CAMetalLayer *layer = mtl_new_layer(mtl_id(device), 1, 1, pixel_format);

#if TARGET_OS_OSX
    SEL setLayer = sel_registerName("setLayer:");
    SEL setWantsLayer = sel_registerName("setWantsLayer:");
    ((void (*)(id, SEL, id))objc_msgSend)(host, setLayer, layer);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(host, setWantsLayer, YES);
#else
    SEL layerSel = sel_registerName("layer");
    id hostLayer = ((id (*)(id, SEL))objc_msgSend)(host, layerSel);
    SEL addSublayer = sel_registerName("addSublayer:");

    if (hostLayer != nil) {
        ((void (*)(id, SEL, id))objc_msgSend)(hostLayer, addSublayer, layer);
    }
#endif

    return mtl_retain_id(layer);
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

void mtl_layer_set_display_sync(void *layer, int32_t enabled)
{
    CAMetalLayer *l = mtl_id(layer);
#if TARGET_OS_OSX
    l.displaySyncEnabled = enabled != 0;
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
