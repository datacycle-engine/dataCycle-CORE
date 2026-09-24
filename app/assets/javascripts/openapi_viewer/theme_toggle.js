// Light/dark toggle for the OpenAPI viewer (/api/config/openapi): the page
// otherwise only follows the OS/browser `prefers-color-scheme` (see
// stylesheets/openapi_viewer/dark.scss), so this lets a visitor override that via
// `document.documentElement.dataset.ovTheme`. Shared toggle mechanics
// (storage, media-query fallback, icon/aria sync) live in
// helpers/theme_toggle_helper.js, alongside schema/theme_toggle.js.
//
// Also keeps the `dark-mode` class on <html> in sync with the effective
// theme — Swagger UI's own bundled dark theme (swagger-ui-dist/swagger-ui.css)
// is keyed off that exact class, and (unlike our own --ov-* tokens) has no
// prefers-color-scheme fallback of its own, so this is the only thing that
// ever turns it on. Called eagerly from openapi_viewer_boot.js, before
// Swagger UI's spec fetch resolves, so its very first paint is already themed.
import createThemeToggle from "../helpers/theme_toggle_helper";

const STORAGE_KEY = "dc-openapi-theme";

export default function initThemeToggle(selector = "[data-ov-theme-toggle]") {
	const { destroy } = createThemeToggle({
		storageKey: STORAGE_KEY,
		target: document.documentElement,
		attribute: "ovTheme",
		button: document.querySelector(selector),
		onRender: (dark) =>
			document.documentElement.classList.toggle("dark-mode", dark),
	});

	return destroy;
}
