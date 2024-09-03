import CopyFromAttribute from "./../components/copy_from_attribute";

export default function () {
	DataCycle.registerAddCallback(
		".copy-from-attribute-feature",
		"copy-from-attribute",
		(e) => new CopyFromAttribute(e),
	);
}
