const globalComponents = import.meta.glob("./global_components/**/*.js", {
	eager: true,
	import: "default",
});

export default function () {
	for (const path in globalComponents) {
		try {
			const gc = globalComponents[path];
			new gc();
		} catch (err) {
			DataCycle.notifications.dispatchEvent(
				new CustomEvent("error", { detail: err }),
			);
		}
	}
}
