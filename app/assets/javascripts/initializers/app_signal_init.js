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
				/DATA_KEY/, // QuillJS Error
				/Cannot read properties of undefined (reading 'mutations')/, // QuillJS Error
				/ResizeObserver loop limit exceeded/,
				/ResizeObserver loop completed with undelivered notifications/,
				/UnhandledPromiseRejectionError/,
			],
		});

		appSignal.use(plugin());
		window.appSignal = appSignal;
	}
}
