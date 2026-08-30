# libmetal

OpenGL after 1.1 is a table of function pointers. Metal is not. Metal is Objective-C objects, `NSError **`, and a `CAMetalLayer`. Echo only speaks C.

So this is Echo's Metal binding: a small Objective-C C ABI in `c/*.m`, then Echo classes that own the returned pointers. You add it with epm. You write `mtl::`. You do not write `objc_msgSend`.

It is a binding, not a renderer. GLFW, UIKit, or your own view still creates the window. This module talks to a layer once one exists, the same way libopengl talks to a context once one exists.

Apple platforms only: macOS, iOS, tvOS. Echo's `os` axis is `darwin` for the whole family. The C shim uses `TargetConditionals.h`. There is no AppKit or UIKit link; those would make the other OS impossible.

## The simple case

```bash
epm add echolang/libmetal --git https://github.com/echolang/libmetal --range ^0.1
```

List devices:

```echo
if (!mtl::available()) {
    die('no Metal device');
}

$all = mtl::Device::all();
echo $all[0]->name();
```

`Device::systemDefault()` is a static because there is nothing to label. A forgotten device is `null`, not a jump to `0x0`.

## Calling

Names follow Metal, with the `MTL` prefix stripped. `MTLDevice` is `mtl::Device`. `newCommandQueue` stays `newCommandQueue`. `MTLPixelFormatBGRA8Unorm` is `PixelFormat::bgra8Unorm`.

Objects are Echo classes. Metal is reference-counted. So are Echo classes. The destructor calls `mtl_release`. Sharing a `Buffer` is sharing the Metal object, which is the honest shape.

A function that can fail returns `result<T, Error>`. Programmer errors (`endEncoding` twice, a null handle) `die`.

```echo
mtl::Device $d = guard mtl::Device::systemDefault() else {
    die('no GPU');
}

mtl::Buffer $b = guard $d->newBuffer(64) else {
    die('no buffer');
}

ptr<uint8> $p = $b->contents();
$p:$[0] = 7;
```

`newBuffer(64)` uses `ResourceOptions::shared`. That is the intersection of macOS and iOS. `managed` is macOS-only. I would not default to it.

`StorageMode::private` is not a case. `private` is an Echo keyword. The Metal private storage mode is `devicePrivate`.

### Labels, names, defaults

Several construction paths are labelled constructors, not static factories:

```echo
$offscreen = mtl::Layer($device, mtl::Size($width: 800, $height: 600));
$fromUi = mtl::Layer(fromPtr: $caMetalLayer);
$fromGlfw = mtl::Layer(attachView: glfw::getCocoaWindow($window), $device);
```

Encoder slots that would swap two `uint32`s take `index:`:

```echo
$enc->setVertexBuffer($vb, index: 0);
$enc->setVertexBytes($uniforms, index: 1);
$enc->drawPrimitives(.triangle, 0, 3);
```

Descriptors are Echo structs with field defaults. You name the fields you set:

```echo
$desc = mtl::TextureDescriptor($pixelFormat: .rgba8Unorm, $width: 256, $height: 256);
$tex = $device->newTexture($desc);
```

`$name:` is caller sugar on an unlabelled parameter. The library does not require it.

## Shaders

MSL, compiled at runtime from an Echo `string`. No `xcrun metal` in the Echo build. That keeps `echoc run` working.

```echo
$src = "#include <metal_stdlib>\nusing namespace metal;\nkernel void fill(device uint *out [[buffer(0)]]) { out[0] = 7; }";
mtl::Library $lib = guard $d->newLibrary(source: $src) else ($e) {
    die($e->message());
}
```

`newLibrary(data: $bytes, $length)` is the prebuilt `.metallib` path.

Here is the catch: `echoc test` forks each test. The Metal shader compiler is XPC. XPC does not survive fork. Shader compile success is an example (`echoc run --target compute`), not a unit test. A syntax error still comes back as `result` without talking to that service, and that one is a test.

## Presenting

This is not a window. On macOS, create a GLFW window with `glfw::NO_API`, then attach:

```echo
glfw::windowHint(glfw::CLIENT_API, glfw::NO_API);
ptr<glfw::Window> $window = glfw::createWindow(800, 600, 'libmetal', null, null);
mtl::Layer $layer = mtl::Layer(attachView: glfw::getCocoaWindow($window), $device);
```

No `makeContextCurrent`. No `gl::load`. No `swapBuffers`. Present is `$cmd->present($drawable)` then `commit`.

On iOS and tvOS the UIKit side owns the `UIView`. Either `+layerClass` returning `[CAMetalLayer class]` and `Layer(fromPtr: view.layer)`, or `Layer(attachView: $uiView, $device)`. libmetal never creates a `UIWindow`.

libmetal does not depend on libglfw. `glfw::getCocoaWindow` lives in libglfw, Darwin only.

## Tests

```bash
cd libmetal
echoc test
```

GPU-free enum values always. Device and buffer tests need a Metal device. They `die` if `available()` is false, so a VM without Metal does not look like an API bug.

## Examples

```bash
cd examples
echoc run --target devices
echoc run --target compute
echoc run --target clear -- --frames 120
echoc run --target triangle -- --frames 120
```

`clear` and `triangle` open a window and close themselves after N swaps.
