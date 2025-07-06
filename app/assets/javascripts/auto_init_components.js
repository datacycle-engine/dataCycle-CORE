const autoInitComponents = import.meta.glob("./auto_init_components/**/*.js", {
	eager: true,
	import: "default",
});

export default function () {
	for (const path in autoInitComponents) {
		try {
			const component = autoInitComponents[path];
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
