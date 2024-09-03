import GravityUiEditor from "../components/gravity_ui_editor";

export default function () {
	DataCycle.registerAddCallback(
		"button.button.change-gravity-ui",
		"gravity-ui-editor",
		(e) => new GravityUiEditor(e),
	);
}
