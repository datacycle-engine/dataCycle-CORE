// Light/dark toggle for /schema (#50201 follow-up): the page otherwise only
// follows the OS/browser `prefers-color-scheme`, so this lets a visitor override
// that per-browser via `document.body.dataset.schemaTheme` (see _dark.scss,
// which reacts to that attribute the same way it reacts to the media query).
// Shared toggle mechanics (storage, media-query fallback, icon/aria sync) live
// in helpers/theme_toggle_helper.js, alongside openapi_viewer/theme_toggle.js.
import createThemeToggle from "../helpers/theme_toggle_helper";

const STORAGE_KEY = "dc-schema-theme";

export default class SchemaThemeToggle {
	static selector = "[data-schema-theme-toggle]";
	static className = "dcjs-schema-theme-toggle";

	constructor(element) {
		// destroy is exposed (mirroring openapi_viewer/theme_toggle.js's cleanup
		// return) rather than discarded, even though nothing calls it today: /schema
		// only ever full-page-navigates (no Turbo Drive, see application.js), so this
		// button is never swapped in place and the matchMedia listener never leaks.
		this.destroy = createThemeToggle({
			storageKey: STORAGE_KEY,
			target: document.body,
			attribute: "schemaTheme",
			button: element,
		}).destroy;
	}
}
