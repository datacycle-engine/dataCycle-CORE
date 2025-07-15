import { showToast } from "../components/toast_notification";

export function showCallout(text, type = "", closeable = true) {
	showToast(text, type, closeable);
}
const CalloutHelpers = {
	show: showCallout,
};

Object.freeze(CalloutHelpers);

export default CalloutHelpers;
