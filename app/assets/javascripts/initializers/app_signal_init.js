import AppSignal from "@appsignal/javascript";
import { plugin } from "@appsignal/plugin-window-events";

export default function (appSignalFrontEndKey) {
	if (
		["production", "staging"].includes(import.meta.env.MODE) &&
		appSignalFrontEndKey
	) {
		const appSignal = new AppSignal({
			key: appSignalFrontEndKey,
			ignoreErrors: [
				/diff() called with non-document/, // QuillJS Error
				/undefined has no properties/, // QuillJS Error
				/Index or size is negative or greater than the allowed amount/, // QuillJS Error
				/domNode[.\.DATA_KEY] is undefined/, // QuillJS Error
				/ResizeObserver loop limit exceeded/,
				/ResizeObserver loop completed with undelivered notifications/,
			],
		});

		appSignal.use(plugin());
		window.appSignal = appSignal;
	}
}
