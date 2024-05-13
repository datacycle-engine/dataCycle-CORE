import EmbeddedObject from "./../components/embedded_object";
import EmbeddedTitle from "../components/embedded_title";

export default function () {
	DataCycle.initNewElements(
		".embedded-object:not(.dcjs-embedded-object)",
		(e) => new EmbeddedObject(e),
	);
	DataCycle.initNewElements(
		".is-embedded-title:not(.dcjs-embedded-title)",
		(e) => new EmbeddedTitle(e),
	);
}
