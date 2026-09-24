// Registers a set of auto-init component classes with DataCycle's html observer.
// Shared by the application-wide glob (auto_init_components.js) and the per-page
// entrypoints (entrypoints/schema.js), so "how a component registers" has one home.
//
// Registering late is safe: DataCycle#registerAddCallback runs the callback over the
// elements already in the DOM before it starts observing for new ones, so a page
// entrypoint loaded after application.js still initializes what is on the page.
export default function registerComponents(components) {
	for (const path in components) {
		try {
			const component = components[path];
			const initFunction = component.lazy
				? "registerLazyAddCallback"
				: "registerAddCallback";

			DataCycle[initFunction](
				component.selector,
				component.className,
				(e) => new component(e),
			);
		} catch (err) {
			DataCycle.notifications.dispatchEvent(
				new CustomEvent("error", { detail: err }),
			);
		}
	}
}
