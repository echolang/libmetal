#import "internal.h"

void *mtl_device_new_library_source(
    void *device,
    const char *source,
    const mtl_compile_opts *opts,
    char *err,
    size_t err_cap)
{
    if (err != NULL && err_cap > 0) {
        err[0] = '\0';
    }

    if (source == NULL) {
        mtl_copy_nsstring(@"empty shader source", err, err_cap);
        return NULL;
    }

    MTLCompileOptions *co = nil;

    if (opts != NULL) {
        co = [[MTLCompileOptions alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        co.fastMathEnabled = opts->fast_math != 0;
#pragma clang diagnostic pop

        if (opts->language_version != 0) {
            co.languageVersion = (MTLLanguageVersion)opts->language_version;
        }
    }

    NSError *error = nil;
    id<MTLDevice> d = mtl_id(device);
    NSString *src = [NSString stringWithUTF8String:source];
    id<MTLLibrary> lib = [d newLibraryWithSource:src options:co error:&error];

    if (lib == nil) {
        mtl_copy_error(error, err, err_cap);
        return NULL;
    }

    return mtl_retain_id(lib);
}

void *mtl_device_new_library_data(
    void *device,
    const void *bytes,
    uint64_t length,
    char *err,
    size_t err_cap)
{
    if (err != NULL && err_cap > 0) {
        err[0] = '\0';
    }

    if (bytes == NULL || length == 0) {
        mtl_copy_nsstring(@"empty metallib data", err, err_cap);
        return NULL;
    }

    dispatch_data_t data = dispatch_data_create(bytes, (size_t)length, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    NSError *error = nil;
    id<MTLDevice> d = mtl_id(device);
    id<MTLLibrary> lib = [d newLibraryWithData:data error:&error];

    if (lib == nil) {
        mtl_copy_error(error, err, err_cap);
        return NULL;
    }

    return mtl_retain_id(lib);
}

void *mtl_library_new_function(void *library, const char *name)
{
    if (name == NULL) {
        return NULL;
    }

    id<MTLLibrary> lib = mtl_id(library);
    return mtl_retain_id([lib newFunctionWithName:[NSString stringWithUTF8String:name]]);
}

static void apply_vertex_desc(MTLRenderPipelineDescriptor *pd, const mtl_vertex_desc *vd)
{
    if (vd == NULL || (vd->attr_count == 0 && vd->layout_count == 0)) {
        return;
    }

    MTLVertexDescriptor *md = [[MTLVertexDescriptor alloc] init];
    uint32_t i;

    for (i = 0; i < vd->attr_count && i < MTL_MAX_VERTEX_ATTR; i++) {
        mtl_vertex_attr a = vd->attrs[i];
        md.attributes[a.index].format = (MTLVertexFormat)a.format;
        md.attributes[a.index].offset = (NSUInteger)a.offset;
        md.attributes[a.index].bufferIndex = (NSUInteger)a.buffer_index;
    }

    for (i = 0; i < vd->layout_count && i < MTL_MAX_VERTEX_LAYOUT; i++) {
        mtl_vertex_layout l = vd->layouts[i];
        md.layouts[l.index].stride = (NSUInteger)l.stride;
        md.layouts[l.index].stepFunction = (MTLVertexStepFunction)l.step_function;
        md.layouts[l.index].stepRate = (NSUInteger)l.step_rate;
    }

    pd.vertexDescriptor = md;
}

void *mtl_device_new_render_pipeline(
    void *device,
    const mtl_render_pipeline *desc,
    char *err,
    size_t err_cap)
{
    if (err != NULL && err_cap > 0) {
        err[0] = '\0';
    }

    if (desc == NULL || desc->vertex_function == NULL) {
        mtl_copy_nsstring(@"render pipeline needs a vertex function", err, err_cap);
        return NULL;
    }

    MTLRenderPipelineDescriptor *pd = [[MTLRenderPipelineDescriptor alloc] init];
    pd.vertexFunction = mtl_id(desc->vertex_function);
    pd.fragmentFunction = mtl_id(desc->fragment_function);

    uint32_t i;
    uint32_t n = desc->color_count;

    if (n > MTL_MAX_COLOR) {
        n = MTL_MAX_COLOR;
    }

    for (i = 0; i < n; i++) {
        pd.colorAttachments[i].pixelFormat = (MTLPixelFormat)desc->color_formats[i];
        pd.colorAttachments[i].blendingEnabled = desc->blending != 0;
        pd.colorAttachments[i].sourceRGBBlendFactor = (MTLBlendFactor)desc->src_rgb;
        pd.colorAttachments[i].destinationRGBBlendFactor = (MTLBlendFactor)desc->dst_rgb;
        pd.colorAttachments[i].rgbBlendOperation = (MTLBlendOperation)desc->rgb_op;
        pd.colorAttachments[i].sourceAlphaBlendFactor = (MTLBlendFactor)desc->src_a;
        pd.colorAttachments[i].destinationAlphaBlendFactor = (MTLBlendFactor)desc->dst_a;
        pd.colorAttachments[i].alphaBlendOperation = (MTLBlendOperation)desc->a_op;
        pd.colorAttachments[i].writeMask = (MTLColorWriteMask)desc->write_mask;
    }

    if (desc->depth_format != 0) {
        pd.depthAttachmentPixelFormat = (MTLPixelFormat)desc->depth_format;
    }

    apply_vertex_desc(pd, &desc->vertex);

    NSError *error = nil;
    id<MTLDevice> d = mtl_id(device);
    id<MTLRenderPipelineState> ps = [d newRenderPipelineStateWithDescriptor:pd error:&error];

    if (ps == nil) {
        mtl_copy_error(error, err, err_cap);
        return NULL;
    }

    return mtl_retain_id(ps);
}

void *mtl_device_new_compute_pipeline(
    void *device,
    void *function,
    char *err,
    size_t err_cap)
{
    if (err != NULL && err_cap > 0) {
        err[0] = '\0';
    }

    if (function == NULL) {
        mtl_copy_nsstring(@"compute pipeline needs a kernel function", err, err_cap);
        return NULL;
    }

    NSError *error = nil;
    id<MTLDevice> d = mtl_id(device);
    id<MTLComputePipelineState> ps = [d newComputePipelineStateWithFunction:mtl_id(function) error:&error];

    if (ps == nil) {
        mtl_copy_error(error, err, err_cap);
        return NULL;
    }

    return mtl_retain_id(ps);
}

void *mtl_device_new_depth_stencil(void *device, const mtl_depth_stencil_desc *desc)
{
    if (desc == NULL) {
        return NULL;
    }

    MTLDepthStencilDescriptor *dd = [[MTLDepthStencilDescriptor alloc] init];
    dd.depthCompareFunction = (MTLCompareFunction)desc->compare;
    dd.depthWriteEnabled = desc->depth_write != 0;

    id<MTLDevice> d = mtl_id(device);
    return mtl_retain_id([d newDepthStencilStateWithDescriptor:dd]);
}
