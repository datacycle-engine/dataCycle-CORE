// Unit tests for the shared light/dark toggle logic (createThemeToggle) used
// by both /schema (schema/theme_toggle.js) and the
// OpenAPI viewer (openapi_viewer/theme_toggle.js): persisted-choice vs OS
// preference resolution, target dataset sync, button icon/aria sync, and
// listener lifecycle. Runs without a DOM — window.matchMedia/localStorage are
// stubbed and target/button are plain fakes, mirroring
// schema_dependency_graph_test.mjs's no-DOM approach.
import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import createThemeToggle from "../../app/assets/javascripts/helpers/theme_toggle_helper.js";

// A minimal MediaQueryList stand-in: starts at `matches` and lets the test
// fire a "change" event (simulating the OS preference flipping) via `set()`.
function fakeMedia(matches) {
	let handler;
	return {
		get matches() {
			return matches;
		},
		addEventListener(type, cb) {
			if (type === "change") handler = cb;
		},
		removeEventListener(type, cb) {
			if (type === "change" && handler === cb) handler = undefined;
		},
		set(value) {
			matches = value;
			handler?.();
		},
		get listenerCount() {
			return handler ? 1 : 0;
		},
	};
}

// A minimal localStorage stand-in, scoped per test (real localStorage is a
// browser global; Node has none).
function fakeStorage() {
	const store = new Map();
	return {
		getItem: (key) => (store.has(key) ? store.get(key) : null),
		setItem: (key, value) => store.set(key, value),
	};
}

// A fake toggle button: tracks its own attributes/title and a child ".fa"
// icon's classes, exactly what render() reads/writes.
function fakeButton(dataAttributes = {}) {
	const attributes = { ...dataAttributes };
	const iconClasses = new Set();
	const icon = {
		classList: {
			toggle(className, force) {
				if (force) iconClasses.add(className);
				else iconClasses.delete(className);
			},
		},
	};
	let clickHandler;

	return {
		title: undefined,
		get iconClasses() {
			return iconClasses;
		},
		get attributes() {
			return attributes;
		},
		querySelector(selector) {
			return selector === ".fa" ? icon : null;
		},
		getAttribute(name) {
			return Object.hasOwn(attributes, name) ? attributes[name] : null;
		},
		setAttribute(name, value) {
			attributes[name] = value;
		},
		addEventListener(type, cb) {
			if (type === "click") clickHandler = cb;
		},
		removeEventListener(type, cb) {
			if (type === "click" && clickHandler === cb) clickHandler = undefined;
		},
		click() {
			clickHandler?.();
		},
		get hasClickListener() {
			return Boolean(clickHandler);
		},
	};
}

function fakeTarget() {
	return { dataset: {} };
}

afterEach(() => {
	delete globalThis.window;
	delete globalThis.localStorage;
});

function setup({ matches = false, storage = fakeStorage() } = {}) {
	const media = fakeMedia(matches);
	globalThis.window = { matchMedia: () => media };
	globalThis.localStorage = storage;
	return { media, storage };
}

test("with no stored preference, follows the OS media query (dark)", () => {
	setup({ matches: true });
	const target = fakeTarget();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme" });

	assert.equal(toggle.isDark(), true);
	assert.equal(target.dataset.theme, undefined, "no override: dataset attribute must stay unset");
});

test("with no stored preference, follows the OS media query (light)", () => {
	setup({ matches: false });
	const target = fakeTarget();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme" });

	assert.equal(toggle.isDark(), false);
	assert.equal(target.dataset.theme, undefined);
});

test("a stored preference wins over the OS media query", () => {
	const storage = fakeStorage();
	storage.setItem("k", "dark");
	setup({ matches: false, storage });
	const target = fakeTarget();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme" });

	assert.equal(toggle.isDark(), true, "stored dark must win even though the OS prefers light");
	assert.equal(target.dataset.theme, "dark", "the forced choice is written to the target dataset");
});

test("onRender receives the resolved dark/light state on every render", () => {
	setup({ matches: true });
	const target = fakeTarget();
	const seen = [];

	createThemeToggle({
		storageKey: "k",
		target,
		attribute: "theme",
		onRender: (dark) => seen.push(dark),
	});

	assert.deepEqual(seen, [true], "onRender must fire once, with the initial resolved state");
});

test("works without a button: target/onRender still sync, nothing throws", () => {
	setup({ matches: true });
	const target = fakeTarget();

	assert.doesNotThrow(() => {
		const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme", button: null });
		toggle.destroy();
	});
});

test("click toggles the stored preference, persists it, and re-renders", () => {
	const { storage } = setup({ matches: false });
	const target = fakeTarget();
	const button = fakeButton();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme", button });

	assert.equal(toggle.isDark(), false, "starts following the (light) OS preference");

	button.click();

	assert.equal(toggle.isDark(), true, "first click forces dark");
	assert.equal(storage.getItem("k"), "dark", "the choice is persisted under the given storage key");
	assert.equal(target.dataset.theme, "dark");

	button.click();

	assert.equal(toggle.isDark(), false, "second click flips back to light");
	assert.equal(storage.getItem("k"), "light");
});

test("render syncs the button icon classes to the resolved theme", () => {
	setup({ matches: false });
	const target = fakeTarget();
	const button = fakeButton();

	createThemeToggle({ storageKey: "k", target, attribute: "theme", button });

	assert.ok(button.iconClasses.has("fa-moon-o"), "light mode shows the moon (switch-to-dark affordance)");
	assert.ok(!button.iconClasses.has("fa-sun-o"));

	button.click();

	assert.ok(button.iconClasses.has("fa-sun-o"), "dark mode shows the sun (switch-to-light affordance)");
	assert.ok(!button.iconClasses.has("fa-moon-o"));
});

test("render sets aria-label/title from the matching data-label-* attribute", () => {
	setup({ matches: false });
	const target = fakeTarget();
	const button = fakeButton({ "data-label-dark": "Enable dark mode", "data-label-light": "Enable light mode" });

	createThemeToggle({ storageKey: "k", target, attribute: "theme", button });

	assert.equal(button.attributes["aria-label"], "Enable dark mode");
	assert.equal(button.title, "Enable dark mode");
	assert.equal(button.attributes["aria-pressed"], "false");

	button.click();

	assert.equal(button.attributes["aria-label"], "Enable light mode");
	assert.equal(button.title, "Enable light mode");
	assert.equal(button.attributes["aria-pressed"], "true");
});

test("render does not set aria-label/title when the button carries no data-label-* attribute", () => {
	setup({ matches: false });
	const target = fakeTarget();
	const button = fakeButton();

	createThemeToggle({ storageKey: "k", target, attribute: "theme", button });

	assert.equal(button.attributes["aria-label"], undefined);
	assert.equal(button.title, undefined);
	assert.equal(button.attributes["aria-pressed"], "false", "aria-pressed is set independently of the label");
});

test("a media-query change re-renders only while no preference is stored", () => {
	const { media } = setup({ matches: false });
	const target = fakeTarget();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme" });

	assert.equal(toggle.isDark(), false);

	media.set(true);
	assert.equal(toggle.isDark(), true, "no stored preference: must follow the OS change live");

	toggle.destroy();
});

test("a media-query change is ignored once a preference is stored (forced choice wins)", () => {
	const { media } = setup({ matches: false });
	const target = fakeTarget();
	const button = fakeButton();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme", button });
	button.click(); // forces dark, regardless of the (light) OS preference

	assert.equal(toggle.isDark(), true);

	media.set(true); // OS "changes" to dark too — must stay a no-op for the forced choice
	assert.equal(toggle.isDark(), true);

	media.set(false); // OS flips back to light — the forced "dark" choice must still win
	assert.equal(toggle.isDark(), true, "a stored preference must not be overridden by OS changes");
});

test("destroy removes both the media-change and click listeners", () => {
	const { media, storage } = setup({ matches: false });
	const target = fakeTarget();
	const button = fakeButton();

	const toggle = createThemeToggle({ storageKey: "k", target, attribute: "theme", button });

	assert.equal(media.listenerCount, 1);
	assert.equal(button.hasClickListener, true);

	toggle.destroy();

	assert.equal(media.listenerCount, 0, "the media-query change listener must be removed");
	assert.equal(button.hasClickListener, false, "the button click listener must be removed");

	// neither an OS change nor a click re-renders or persists anything anymore
	media.set(true);
	button.click();

	assert.equal(button.attributes["aria-pressed"], "false", "destroyed toggle must no longer re-render on OS or click events");
	assert.equal(storage.getItem("k"), null, "a click after destroy must not persist a preference");
});

test("two toggles using different storage keys do not leak state into each other", () => {
	const { storage } = setup({ matches: false });
	const schemaTarget = fakeTarget();
	const ovTarget = fakeTarget();
	const schemaButton = fakeButton();

	const schemaToggle = createThemeToggle({ storageKey: "dc-schema-theme", target: schemaTarget, attribute: "schemaTheme", button: schemaButton });
	const ovToggle = createThemeToggle({ storageKey: "dc-openapi-theme", target: ovTarget, attribute: "ovTheme" });

	schemaButton.click(); // forces dark, but only under the schema storage key

	assert.equal(schemaToggle.isDark(), true);
	assert.equal(storage.getItem("dc-schema-theme"), "dark");
	assert.equal(storage.getItem("dc-openapi-theme"), null, "the openapi key must be untouched");
	assert.equal(ovToggle.isDark(), false, "the openapi toggle must not pick up the schema toggle's stored preference");
	assert.equal(ovTarget.dataset.ovTheme, undefined);
});
