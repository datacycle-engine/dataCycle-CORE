// Self-initializing entrypoint for the OpenAPI (Swagger UI) viewer. Host projects
// only need a one-line Vite entrypoint that imports this module — the boot logic
// lives here so it stays in sync with the viewer implementation (#50192).
import initOpenApiViewer from './openapi_viewer';
import initThemeToggle from './openapi_viewer/theme_toggle';

let cleanupTheme;
let cleanupViewer;

function boot() {
  // theme first: sets the `dark-mode` class before Swagger UI's spec fetch
  // resolves, so its very first paint (and ours) is already themed.
  cleanupTheme = initThemeToggle();
  cleanupViewer = initOpenApiViewer();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}

// Cleanup observers if the page is navigated (SPA-like contexts)
if (window.Turbo) {
  document.addEventListener('turbo:before-cache', () => {
    cleanupViewer?.();
    cleanupTheme?.();
  });
}
