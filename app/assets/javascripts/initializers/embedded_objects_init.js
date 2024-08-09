import EmbeddedObject from "./../components/embedded_object";
import EmbeddedTitle from "../components/embedded_title";

export default function () {
	DataCycle.registerAddCallback(
		".embedded-object",
		"embedded-object",
		(e) => new EmbeddedObject(e),
	);
	DataCycle.registerAddCallback(
		".is-embedded-title",
		"embedded-title",
		(e) => new EmbeddedTitle(e),
	);
}
