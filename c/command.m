#import "internal.h"

#include <stddef.h>

static NSString *mtl_label(const char *label)
{
    return label != NULL ? [NSString stringWithUTF8String:label] : nil;
}

static void mtl_encoder_set_label(id<MTLCommandEncoder> e, const char *label)
{
    e.label = mtl_label(label);
}

static void mtl_encoder_push_debug_group(id<MTLCommandEncoder> e, const char *label)
{
    [e pushDebugGroup:label != NULL ? [NSString stringWithUTF8String:label] : @""];
}

static void mtl_encoder_pop_debug_group(id<MTLCommandEncoder> e)
{
    [e popDebugGroup];
}

/* sampleCountersInBuffer is on render/blit/compute, not MTLCommandEncoder */
static void mtl_encoder_sample_counters(id e, void *buf, uint64_t index, int32_t barrier)
{
    if (buf == NULL) {
        return;
    }

    if (@available(macOS 10.15, iOS 14.0, tvOS 14.0, *)) {
        [e sampleCountersInBuffer:mtl_id(buf)
                    atSampleIndex:(NSUInteger)index
                      withBarrier:barrier != 0];
    }
}

void *mtl_queue_command_buffer(void *queue)
{
    id<MTLCommandQueue> q = mtl_id(queue);
    return mtl_retain_id([q commandBuffer]);
}

void mtl_command_commit(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    [c commit];
}

void mtl_command_wait(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    [c waitUntilCompleted];
}

double mtl_command_gpu_start(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    if (c.status != MTLCommandBufferStatusCompleted) {
        return 0.0;
    }

    return c.GPUStartTime;
}

double mtl_command_gpu_end(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    if (c.status != MTLCommandBufferStatusCompleted) {
        return 0.0;
    }

    return c.GPUEndTime;
}

double mtl_command_kernel_start(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    if (c.status != MTLCommandBufferStatusCompleted) {
        return 0.0;
    }

    return c.kernelStartTime;
}

double mtl_command_kernel_end(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    if (c.status != MTLCommandBufferStatusCompleted) {
        return 0.0;
    }

    return c.kernelEndTime;
}

void mtl_command_present(void *cmd, void *drawable)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    id<MTLDrawable> d = mtl_id(drawable);
    [c presentDrawable:d];
}

void mtl_command_present_after(void *cmd, void *drawable, double seconds)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    id<MTLDrawable> d = mtl_id(drawable);
#if TARGET_OS_IPHONE
    /* simulator/device headers omit presentDrawable:afterMinimumDuration: */
    (void)seconds;
    [c presentDrawable:d];
#else
    [c presentDrawable:d afterMinimumDuration:seconds];
#endif
}

void mtl_command_signal_event(void *cmd, void *event, uint64_t value)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    [c encodeSignalEvent:mtl_id(event) value:value];
}

void mtl_command_wait_event(void *cmd, void *event, uint64_t value)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    [c encodeWaitForEvent:mtl_id(event) value:value];
}

void *mtl_command_render(void *cmd, const mtl_render_pass *pass)
{
    if (pass == NULL) {
        return NULL;
    }

    MTLRenderPassDescriptor *pd = [MTLRenderPassDescriptor renderPassDescriptor];
    uint32_t i;
    uint32_t n = pass->color_count;

    if (n > MTL_MAX_COLOR) {
        n = MTL_MAX_COLOR;
    }

    for (i = 0; i < n; i++) {
        MTLRenderPassColorAttachmentDescriptor *ca = pd.colorAttachments[i];
        ca.texture = mtl_id(pass->colors[i].texture);
        ca.loadAction = (MTLLoadAction)pass->colors[i].load_action;
        ca.storeAction = (MTLStoreAction)pass->colors[i].store_action;
        ca.level = (NSUInteger)pass->colors[i].level;
        ca.slice = (NSUInteger)pass->colors[i].slice;
        ca.clearColor = MTLClearColorMake(
            pass->colors[i].clear.r,
            pass->colors[i].clear.g,
            pass->colors[i].clear.b,
            pass->colors[i].clear.a);
    }

    if (pass->depth_texture != NULL) {
        pd.depthAttachment.texture = mtl_id(pass->depth_texture);
        pd.depthAttachment.loadAction = (MTLLoadAction)pass->depth_load;
        pd.depthAttachment.storeAction = (MTLStoreAction)pass->depth_store;
        pd.depthAttachment.clearDepth = (double)pass->depth_clear;
        pd.depthAttachment.level = (NSUInteger)pass->depth_level;
        pd.depthAttachment.slice = (NSUInteger)pass->depth_slice;
    }

    if (pass->sample.sample_buffer != NULL) {
        MTLRenderPassSampleBufferAttachmentDescriptor *sa = pd.sampleBufferAttachments[0];
        sa.sampleBuffer = mtl_id(pass->sample.sample_buffer);
        sa.startOfVertexSampleIndex = (NSUInteger)pass->sample.index[0];
        sa.endOfVertexSampleIndex = (NSUInteger)pass->sample.index[1];
        sa.startOfFragmentSampleIndex = (NSUInteger)pass->sample.index[2];
        sa.endOfFragmentSampleIndex = (NSUInteger)pass->sample.index[3];
    }

    id<MTLCommandBuffer> c = mtl_id(cmd);
    return mtl_retain_id([c renderCommandEncoderWithDescriptor:pd]);
}

_Static_assert(sizeof(mtl_render_pass) == 528, "mtl_render_pass layout drifted from AbiRenderPass");
_Static_assert(offsetof(mtl_render_pass, sample) == 488, "mtl_render_pass.sample offset drifted from AbiRenderPass");
_Static_assert(sizeof(mtl_blit_pass) == 40, "mtl_blit_pass layout drifted from AbiBlitPass");
_Static_assert(sizeof(mtl_compute_pass) == 40, "mtl_compute_pass layout drifted from AbiComputePass");

void *mtl_command_blit(void *cmd, const mtl_blit_pass *pass)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);

    if (pass == NULL || pass->sample.sample_buffer == NULL) {
        return mtl_retain_id([c blitCommandEncoder]);
    }

    if (@available(macOS 11.0, iOS 14.0, tvOS 14.0, *)) {
        MTLBlitPassDescriptor *bd = [MTLBlitPassDescriptor blitPassDescriptor];
        MTLBlitPassSampleBufferAttachmentDescriptor *sa = bd.sampleBufferAttachments[0];
        sa.sampleBuffer = mtl_id(pass->sample.sample_buffer);
        sa.startOfEncoderSampleIndex = (NSUInteger)pass->sample.index[0];
        sa.endOfEncoderSampleIndex = (NSUInteger)pass->sample.index[1];
        return mtl_retain_id([c blitCommandEncoderWithDescriptor:bd]);
    }

    return NULL;
}

uint32_t mtl_command_status(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    return (uint32_t)c.status;
}

void mtl_command_set_label(void *cmd, const char *label)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    c.label = mtl_label(label);
}

void mtl_command_push_debug_group(void *cmd, const char *label)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    [c pushDebugGroup:label != NULL ? [NSString stringWithUTF8String:label] : @""];
}

void mtl_command_pop_debug_group(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    [c popDebugGroup];
}

void mtl_blit_generate_mipmaps(void *enc, void *texture)
{
    id<MTLBlitCommandEncoder> e = mtl_id(enc);
    [e generateMipmapsForTexture:mtl_id(texture)];
}

void *mtl_command_compute_pass(void *cmd, const mtl_compute_pass *pass)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);

    if (pass == NULL || pass->sample.sample_buffer == NULL) {
        return mtl_retain_id([c computeCommandEncoder]);
    }

    if (@available(macOS 11.0, iOS 14.0, tvOS 14.0, *)) {
        MTLComputePassDescriptor *pd = [MTLComputePassDescriptor computePassDescriptor];
        MTLComputePassSampleBufferAttachmentDescriptor *sa = pd.sampleBufferAttachments[0];
        sa.sampleBuffer = mtl_id(pass->sample.sample_buffer);
        sa.startOfEncoderSampleIndex = (NSUInteger)pass->sample.index[0];
        sa.endOfEncoderSampleIndex = (NSUInteger)pass->sample.index[1];
        return mtl_retain_id([c computeCommandEncoderWithDescriptor:pd]);
    }

    return NULL;
}

void *mtl_command_compute(void *cmd)
{
    return mtl_command_compute_pass(cmd, NULL);
}

void mtl_render_end(void *enc)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e endEncoding];
}

void mtl_render_set_label(void *enc, const char *label)
{
    mtl_encoder_set_label(mtl_id(enc), label);
}

void mtl_render_push_debug_group(void *enc, const char *label)
{
    mtl_encoder_push_debug_group(mtl_id(enc), label);
}

void mtl_render_pop_debug_group(void *enc)
{
    mtl_encoder_pop_debug_group(mtl_id(enc));
}

void mtl_render_sample_counters(void *enc, void *buf, uint64_t index, int32_t barrier)
{
    mtl_encoder_sample_counters(mtl_id(enc), buf, index, barrier);
}

void mtl_render_set_pipeline(void *enc, void *pipeline)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setRenderPipelineState:mtl_id(pipeline)];
}

void mtl_render_set_depth_stencil(void *enc, void *state)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setDepthStencilState:mtl_id(state)];
}

void mtl_render_set_vertex_buffer(void *enc, void *buffer, uint64_t offset, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setVertexBuffer:mtl_id(buffer) offset:(NSUInteger)offset atIndex:(NSUInteger)index];
}

void mtl_render_set_fragment_buffer(void *enc, void *buffer, uint64_t offset, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setFragmentBuffer:mtl_id(buffer) offset:(NSUInteger)offset atIndex:(NSUInteger)index];
}

void mtl_render_set_vertex_bytes(void *enc, const void *bytes, uint64_t length, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setVertexBytes:bytes length:(NSUInteger)length atIndex:(NSUInteger)index];
}

void mtl_render_set_fragment_bytes(void *enc, const void *bytes, uint64_t length, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setFragmentBytes:bytes length:(NSUInteger)length atIndex:(NSUInteger)index];
}

void mtl_render_set_fragment_texture(void *enc, void *texture, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setFragmentTexture:mtl_id(texture) atIndex:(NSUInteger)index];
}

void mtl_render_set_fragment_sampler(void *enc, void *sampler, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setFragmentSamplerState:mtl_id(sampler) atIndex:(NSUInteger)index];
}

void mtl_render_set_vertex_texture(void *enc, void *texture, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setVertexTexture:mtl_id(texture) atIndex:(NSUInteger)index];
}

void mtl_render_set_vertex_sampler(void *enc, void *sampler, uint32_t index)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setVertexSamplerState:mtl_id(sampler) atIndex:(NSUInteger)index];
}

void mtl_render_set_tessellation_factor_buffer(
    void *enc,
    void *buffer,
    uint64_t offset,
    uint32_t instance_stride)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setTessellationFactorBuffer:mtl_id(buffer)
                           offset:(NSUInteger)offset
                   instanceStride:(NSUInteger)instance_stride];
}

void mtl_render_set_viewport(
    void *enc,
    double origin_x,
    double origin_y,
    double width,
    double height,
    double znear,
    double zfar)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    MTLViewport v = { origin_x, origin_y, width, height, znear, zfar };
    [e setViewport:v];
}

void mtl_render_set_scissor(void *enc, uint32_t x, uint32_t y, uint32_t width, uint32_t height)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    MTLScissorRect r = { (NSUInteger)x, (NSUInteger)y, (NSUInteger)width, (NSUInteger)height };
    [e setScissorRect:r];
}

void mtl_render_set_cull(void *enc, uint32_t mode)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setCullMode:(MTLCullMode)mode];
}

void mtl_render_set_winding(void *enc, uint32_t winding)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setFrontFacingWinding:(MTLWinding)winding];
}

void mtl_render_set_triangle_fill(void *enc, uint32_t mode)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e setTriangleFillMode:(MTLTriangleFillMode)mode];
}

void mtl_render_draw(void *enc, uint32_t primitive, uint32_t start, uint32_t count, uint32_t instances)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e drawPrimitives:(MTLPrimitiveType)primitive
          vertexStart:(NSUInteger)start
          vertexCount:(NSUInteger)count
        instanceCount:(NSUInteger)instances];
}

void mtl_render_draw_indexed(
    void *enc,
    uint32_t primitive,
    uint32_t index_count,
    uint32_t index_type,
    void *index_buffer,
    uint64_t index_offset,
    uint32_t instances)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e drawIndexedPrimitives:(MTLPrimitiveType)primitive
                  indexCount:(NSUInteger)index_count
                   indexType:(MTLIndexType)index_type
                 indexBuffer:mtl_id(index_buffer)
           indexBufferOffset:(NSUInteger)index_offset
               instanceCount:(NSUInteger)instances];
}

void mtl_render_draw_patches(
    void *enc,
    uint32_t control_points,
    uint32_t patch_start,
    uint32_t patch_count,
    uint32_t instances)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e drawPatches:(NSUInteger)control_points
        patchStart:(NSUInteger)patch_start
        patchCount:(NSUInteger)patch_count
  patchIndexBuffer:nil
patchIndexBufferOffset:0
     instanceCount:(NSUInteger)instances
      baseInstance:0];
}

void mtl_blit_end(void *enc)
{
    id<MTLBlitCommandEncoder> e = mtl_id(enc);
    [e endEncoding];
}

void mtl_blit_set_label(void *enc, const char *label)
{
    mtl_encoder_set_label(mtl_id(enc), label);
}

void mtl_blit_push_debug_group(void *enc, const char *label)
{
    mtl_encoder_push_debug_group(mtl_id(enc), label);
}

void mtl_blit_pop_debug_group(void *enc)
{
    mtl_encoder_pop_debug_group(mtl_id(enc));
}

void mtl_blit_sample_counters(void *enc, void *buf, uint64_t index, int32_t barrier)
{
    mtl_encoder_sample_counters(mtl_id(enc), buf, index, barrier);
}

void mtl_blit_copy_buffer(
    void *enc,
    void *src,
    uint64_t src_offset,
    void *dst,
    uint64_t dst_offset,
    uint64_t size)
{
    id<MTLBlitCommandEncoder> e = mtl_id(enc);
    [e copyFromBuffer:mtl_id(src)
         sourceOffset:(NSUInteger)src_offset
             toBuffer:mtl_id(dst)
    destinationOffset:(NSUInteger)dst_offset
                 size:(NSUInteger)size];
}

void mtl_blit_copy_texture(
    void *enc,
    void *src,
    uint32_t src_slice,
    uint32_t src_level,
    uint64_t src_ox,
    uint64_t src_oy,
    uint64_t src_oz,
    uint64_t width,
    uint64_t height,
    uint64_t depth,
    void *dst,
    uint32_t dst_slice,
    uint32_t dst_level,
    uint64_t dst_ox,
    uint64_t dst_oy,
    uint64_t dst_oz)
{
    id<MTLBlitCommandEncoder> e = mtl_id(enc);
    [e copyFromTexture:mtl_id(src)
           sourceSlice:(NSUInteger)src_slice
           sourceLevel:(NSUInteger)src_level
          sourceOrigin:MTLOriginMake((NSUInteger)src_ox, (NSUInteger)src_oy, (NSUInteger)src_oz)
            sourceSize:MTLSizeMake((NSUInteger)width, (NSUInteger)height, (NSUInteger)depth)
             toTexture:mtl_id(dst)
      destinationSlice:(NSUInteger)dst_slice
      destinationLevel:(NSUInteger)dst_level
     destinationOrigin:MTLOriginMake((NSUInteger)dst_ox, (NSUInteger)dst_oy, (NSUInteger)dst_oz)];
}

void mtl_compute_end(void *enc)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    [e endEncoding];
}

void mtl_compute_set_label(void *enc, const char *label)
{
    mtl_encoder_set_label(mtl_id(enc), label);
}

void mtl_compute_push_debug_group(void *enc, const char *label)
{
    mtl_encoder_push_debug_group(mtl_id(enc), label);
}

void mtl_compute_pop_debug_group(void *enc)
{
    mtl_encoder_pop_debug_group(mtl_id(enc));
}

void mtl_compute_sample_counters(void *enc, void *buf, uint64_t index, int32_t barrier)
{
    mtl_encoder_sample_counters(mtl_id(enc), buf, index, barrier);
}

void mtl_compute_set_pipeline(void *enc, void *pipeline)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    [e setComputePipelineState:mtl_id(pipeline)];
}

void mtl_compute_set_buffer(void *enc, void *buffer, uint64_t offset, uint32_t index)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    [e setBuffer:mtl_id(buffer) offset:(NSUInteger)offset atIndex:(NSUInteger)index];
}

void mtl_compute_set_bytes(void *enc, const void *bytes, uint64_t length, uint32_t index)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    [e setBytes:bytes length:(NSUInteger)length atIndex:(NSUInteger)index];
}

void mtl_compute_set_texture(void *enc, void *texture, uint32_t index)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    [e setTexture:mtl_id(texture) atIndex:(NSUInteger)index];
}

void mtl_compute_dispatch(
    void *enc,
    uint64_t tw,
    uint64_t th,
    uint64_t td,
    uint64_t gw,
    uint64_t gh,
    uint64_t gd)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    MTLSize grid = MTLSizeMake((NSUInteger)tw, (NSUInteger)th, (NSUInteger)td);
    MTLSize group = MTLSizeMake((NSUInteger)gw, (NSUInteger)gh, (NSUInteger)gd);
    [e dispatchThreads:grid threadsPerThreadgroup:group];
}
