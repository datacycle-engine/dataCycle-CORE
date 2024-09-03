import AttributeLocaleSwitcher from "../components/attribute_locale_switcher";

export default function () {
	DataCycle.registerAddCallback(
		".attribute-locale-switcher",
		"attribute-locale-switcher",
		(e) => new AttributeLocaleSwitcher(e),
	);
}
