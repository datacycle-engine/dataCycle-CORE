const ColorPicker = () => import("../components/color_picker");

function initColorPicker(element) {
	element.classList.add("dcjs-color-picker");
	ColorPicker().then((mod) => new mod.default(element));
}

export default function () {
	DataCycle.initNewElements(
		".dc-color-picker:not(.dcjs-color-picker)",
		initColorPicker.bind(this),
	);
}
