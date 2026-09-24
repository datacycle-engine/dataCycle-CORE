// Shared light/dark toggle behaviour for the /schema and OpenAPI-viewer pages
// (see schema/theme_toggle.js and
// openapi_viewer/theme_toggle.js): an explicit choice is persisted to
// localStorage and wins over the OS/browser `prefers-color-scheme`; leaving it
// unset falls back to the OS preference, including live updates while that
// preference changes. Each caller only supplies where the resolved theme is
// written (a dataset attribute on its own root element) and, optionally, a
// button whose icon/aria state should track it.
export default function createThemeToggle({
	storageKey,
	target,
	attribute,
	button,
	onRender,
}) {
	const media = window.matchMedia("(prefers-color-scheme: dark)");
	let stored = localStorage.getItem(storageKey);

	const isDark = () => (stored ? stored === "dark" : media.matches);

	const render = () => {
		const dark = isDark();

		if (stored) target.dataset[attribute] = stored;
		else delete target.dataset[attribute];

		onRender?.(dark);

		if (button) {
			const icon = button.querySelector(".fa");
			icon?.classList.toggle("fa-sun-o", dark);
			icon?.classList.toggle("fa-moon-o", !dark);

			const label = button.getAttribute(
				dark ? "data-label-light" : "data-label-dark",
			);
			if (label) {
				button.setAttribute("aria-label", label);
				button.title = label;
			}
			button.setAttribute("aria-pressed", String(dark));
		}

		return dark;
	};

	const onMediaChange = () => {
		if (!stored) render();
	};
	media.addEventListener("change", onMediaChange);

	const onClick = () => {
		stored = isDark() ? "light" : "dark";
		localStorage.setItem(storageKey, stored);
		render();
	};
	button?.addEventListener("click", onClick);

	render();

	return {
		isDark,
		destroy() {
			media.removeEventListener("change", onMediaChange);
			button?.removeEventListener("click", onClick);
		},
	};
}
