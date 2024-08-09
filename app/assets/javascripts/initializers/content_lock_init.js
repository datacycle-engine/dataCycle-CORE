import ContentLock from "../components/content_lock";

export default function () {
	DataCycle.registerAddCallback(
		".content-lock",
		"content-lock",
		(e) => new ContentLock(e),
	);
}
