const initializers = import.meta.glob("./initializers/*.js", {
	eager: true,
	import: "default",
});

const initializerExceptions = [
	"foundation_init",
	"validation_init",
	"app_signal_init",
];

export default function () {
	for (const path in initializers) {
		if (!initializerExceptions.some((e) => path.includes(e))) {
			try {
				initializers[path]();
			} catch (err) {
				DataCycle.notifications.dispatchEvent(
					new CustomEvent("error", { detail: err }),
				);
			}
		}
	}
}
