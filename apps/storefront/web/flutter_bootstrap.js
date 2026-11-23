{{flutter_js}}
{{flutter_build_config}}

// Phone performance: Chrome's default CanvasKit rasterizer draws every frame
// to an OffscreenCanvas and copies it to the screen (createImageBitmap +
// transferFromImageBitmap); on phones that copy took most of each animation
// frame. The multi-surface rasterizer draws straight to the on-screen
// canvas, as Flutter already does on Safari and Firefox. Desktop measured
// the same either way, so it keeps Flutter's default.
// window.menovaPhone is set by index.html. See docs/PERF_ON_PHONE.md.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    canvasKitForceMultiSurfaceRasterizer: !!window.menovaPhone,
  },
});
