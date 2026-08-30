#import "internal.h"

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

void mtl_command_present(void *cmd, void *drawable)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    id<MTLDrawable> d = mtl_id(drawable);
    [c presentDrawable:d];
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
    }

    id<MTLCommandBuffer> c = mtl_id(cmd);
    return mtl_retain_id([c renderCommandEncoderWithDescriptor:pd]);
}

void *mtl_command_blit(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    return mtl_retain_id([c blitCommandEncoder]);
}

void *mtl_command_compute(void *cmd)
{
    id<MTLCommandBuffer> c = mtl_id(cmd);
    return mtl_retain_id([c computeCommandEncoder]);
}

void mtl_render_end(void *enc)
{
    id<MTLRenderCommandEncoder> e = mtl_id(enc);
    [e endEncoding];
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

void mtl_blit_end(void *enc)
{
    id<MTLBlitCommandEncoder> e = mtl_id(enc);
    [e endEncoding];
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

void mtl_compute_end(void *enc)
{
    id<MTLComputeCommandEncoder> e = mtl_id(enc);
    [e endEncoding];
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
