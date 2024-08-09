const ColorPicker = () => import("../components/color_picker");

function initColorPicker(element) {
	ColorPicker().then((mod) => new mod.default(element));
}

export default function () {
	DataCycle.registerAddCallback(
		".dc-color-picker",
		"color-picker",
		initColorPicker.bind(this),
	);
}
