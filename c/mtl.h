#ifndef ECHO_MTL_H
#define ECHO_MTL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Every object pointer returned to Echo is +1 retained. Echo calls
 * mtl_release in the class destructor. Pointers Echo passes back in are
 * borrowed (__bridge).
 */

void mtl_retain(void *obj);
void mtl_release(void *obj);

typedef struct {
    uint64_t width;
    uint64_t height;
    uint64_t depth;
} mtl_size;

typedef struct {
    uint64_t x;
    uint64_t y;
    uint64_t z;
} mtl_origin;

typedef struct {
    mtl_origin origin;
    mtl_size size;
} mtl_region;

typedef struct {
    double origin_x;
    double origin_y;
    double width;
    double height;
    double znear;
    double zfar;
} mtl_viewport;

typedef struct {
    double r;
    double g;
    double b;
    double a;
} mtl_clear_color;

typedef struct {
    uint32_t x;
    uint32_t y;
    uint32_t width;
    uint32_t height;
} mtl_scissor;

typedef struct {
    uint32_t texture_type;
    uint32_t pixel_format;
    uint64_t width;
    uint64_t height;
    uint64_t depth;
    uint64_t mipmap_level_count;
    uint64_t sample_count;
    uint64_t array_length;
    uint32_t usage;
    uint32_t storage_mode;
} mtl_texture_desc;

typedef struct {
    uint32_t min_filter;
    uint32_t mag_filter;
    uint32_t mip_filter;
    uint32_t s_address;
    uint32_t t_address;
    uint32_t r_address;
    uint32_t normalized;
} mtl_sampler_desc;

typedef struct {
    int32_t fast_math;
    uint32_t language_version; /* 0 = Metal default */
} mtl_compile_opts;

typedef struct {
    uint32_t index;
    uint32_t format;
    uint32_t offset;
    uint32_t buffer_index;
} mtl_vertex_attr;

typedef struct {
    uint32_t index;
    uint32_t stride;
    uint32_t step_function;
    uint32_t step_rate;
} mtl_vertex_layout;

#define MTL_MAX_VERTEX_ATTR 8
#define MTL_MAX_VERTEX_LAYOUT 4
#define MTL_MAX_COLOR 8

typedef struct {
    mtl_vertex_attr attrs[MTL_MAX_VERTEX_ATTR];
    uint32_t attr_count;
    mtl_vertex_layout layouts[MTL_MAX_VERTEX_LAYOUT];
    uint32_t layout_count;
} mtl_vertex_desc;

typedef struct {
    void *vertex_function;
    void *fragment_function;
    uint32_t color_formats[MTL_MAX_COLOR];
    uint32_t color_count;
    uint32_t depth_format;
    mtl_vertex_desc vertex;
} mtl_render_pipeline;

typedef struct {
    uint32_t compare;
    int32_t depth_write;
} mtl_depth_stencil_desc;

typedef struct {
    void *texture;
    uint32_t load_action;
    uint32_t store_action;
    mtl_clear_color clear;
} mtl_color_attach;

typedef struct {
    mtl_color_attach colors[MTL_MAX_COLOR];
    uint32_t color_count;
    void *depth_texture;
    uint32_t depth_load;
    uint32_t depth_store;
    float depth_clear;
} mtl_render_pass;

/* device */

void *mtl_device_default(void);
uint64_t mtl_device_count(void);
void *mtl_device_at(uint64_t i);
void mtl_device_name(void *device, char *buf, size_t cap);
void *mtl_device_new_queue(void *device, const char *label);
void *mtl_device_new_buffer(void *device, uint64_t length, uint32_t options);
void *mtl_device_new_buffer_bytes(void *device, const void *bytes, uint64_t length, uint32_t options);
void *mtl_device_new_texture(void *device, const mtl_texture_desc *desc);
void *mtl_device_new_sampler(void *device, const mtl_sampler_desc *desc);
void *mtl_device_new_library_source(
    void *device,
    const char *source,
    const mtl_compile_opts *opts,
    char *err,
    size_t err_cap);
void *mtl_device_new_library_data(
    void *device,
    const void *bytes,
    uint64_t length,
    char *err,
    size_t err_cap);
void *mtl_device_new_render_pipeline(
    void *device,
    const mtl_render_pipeline *desc,
    char *err,
    size_t err_cap);
void *mtl_device_new_compute_pipeline(
    void *device,
    void *function,
    char *err,
    size_t err_cap);
void *mtl_device_new_depth_stencil(void *device, const mtl_depth_stencil_desc *desc);

/* buffer / texture */

uint64_t mtl_buffer_length(void *buffer);
void *mtl_buffer_contents(void *buffer);
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
    uint64_t bytes_per_row);
uint64_t mtl_texture_width(void *texture);
uint64_t mtl_texture_height(void *texture);

/* library / function */

void *mtl_library_new_function(void *library, const char *name);

/* command queue / buffer */

void *mtl_queue_command_buffer(void *queue);
void mtl_command_commit(void *cmd);
void mtl_command_wait(void *cmd);
void mtl_command_present(void *cmd, void *drawable);
void *mtl_command_render(void *cmd, const mtl_render_pass *pass);
void *mtl_command_blit(void *cmd);
void *mtl_command_compute(void *cmd);

/* render encoder */

void mtl_render_end(void *enc);
void mtl_render_set_pipeline(void *enc, void *pipeline);
void mtl_render_set_depth_stencil(void *enc, void *state);
void mtl_render_set_vertex_buffer(void *enc, void *buffer, uint64_t offset, uint32_t index);
void mtl_render_set_fragment_buffer(void *enc, void *buffer, uint64_t offset, uint32_t index);
void mtl_render_set_vertex_bytes(void *enc, const void *bytes, uint64_t length, uint32_t index);
void mtl_render_set_fragment_bytes(void *enc, const void *bytes, uint64_t length, uint32_t index);
void mtl_render_set_fragment_texture(void *enc, void *texture, uint32_t index);
void mtl_render_set_fragment_sampler(void *enc, void *sampler, uint32_t index);
void mtl_render_set_viewport(
    void *enc,
    double origin_x,
    double origin_y,
    double width,
    double height,
    double znear,
    double zfar);
void mtl_render_set_scissor(void *enc, uint32_t x, uint32_t y, uint32_t width, uint32_t height);
void mtl_render_set_cull(void *enc, uint32_t mode);
void mtl_render_set_winding(void *enc, uint32_t winding);
void mtl_render_draw(void *enc, uint32_t primitive, uint32_t start, uint32_t count, uint32_t instances);
void mtl_render_draw_indexed(
    void *enc,
    uint32_t primitive,
    uint32_t index_count,
    uint32_t index_type,
    void *index_buffer,
    uint64_t index_offset,
    uint32_t instances);

/* blit encoder */

void mtl_blit_end(void *enc);
void mtl_blit_copy_buffer(
    void *enc,
    void *src,
    uint64_t src_offset,
    void *dst,
    uint64_t dst_offset,
    uint64_t size);

/* compute encoder */

void mtl_compute_end(void *enc);
void mtl_compute_set_pipeline(void *enc, void *pipeline);
void mtl_compute_set_buffer(void *enc, void *buffer, uint64_t offset, uint32_t index);
void mtl_compute_set_bytes(void *enc, const void *bytes, uint64_t length, uint32_t index);
void mtl_compute_set_texture(void *enc, void *texture, uint32_t index);
void mtl_compute_dispatch(
    void *enc,
    uint64_t tw,
    uint64_t th,
    uint64_t td,
    uint64_t gw,
    uint64_t gh,
    uint64_t gd);

/* layer / drawable */

void *mtl_layer_create(void *device, uint64_t width, uint64_t height, uint32_t pixel_format);
void *mtl_layer_from_ptr(void *layer);
void *mtl_layer_attach_view(void *device, void *view, uint32_t pixel_format);
void mtl_layer_set_device(void *layer, void *device);
void mtl_layer_set_pixel_format(void *layer, uint32_t format);
void mtl_layer_set_drawable_size(void *layer, uint64_t width, uint64_t height);
void mtl_layer_get_drawable_size(void *layer, uint64_t *width, uint64_t *height);
void mtl_layer_set_contents_scale(void *layer, double scale);
double mtl_layer_contents_scale(void *layer);
void mtl_layer_set_framebuffer_only(void *layer, int32_t only);
void *mtl_layer_next_drawable(void *layer);
void *mtl_drawable_texture(void *drawable);

#ifdef __cplusplus
}
#endif

#endif
