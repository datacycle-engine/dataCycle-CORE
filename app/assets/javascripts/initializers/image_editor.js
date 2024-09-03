import ImageEditor from "../components/image_editor";

export default function () {
	DataCycle.registerAddCallback(
		".image-editor-reveal",
		"image-editor",
		(e) => new ImageEditor(e),
	);
}
