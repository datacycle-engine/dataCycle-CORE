import NewContentDialog from "./../components/new_content_dialog";
import DragAndDropField from "../components/drag_and_drop_field";
import loadingIcon from "../templates/loadingIcon";

export default function () {
	DataCycle.registerAddCallback(
		"form.new-content-multi-step-form",
		"new-content-dialog",
		(e) => new NewContentDialog(e),
	);
	DataCycle.registerAddCallback(
		".content-uploader",
		"drag-and-drop-field",
		(e) => new DragAndDropField(e),
	);

	$(document).on(
		"ajax:before",
		".new-content-reveal [data-remote]",
		(event) => {
			$(event.target)
				.closest(".new-content-reveal")
				.find(".new-content-form")
				.html(loadingIcon("show"));
		},
	);

	$(document).on(
		"ajax:error",
		".new-content-reveal [data-remote]",
		async (event) => {
			$(event.target)
				.closest(".new-content-reveal")
				.find(".new-content-form")
				.html(await I18n.translate("frontend.load_error"));
		},
	);
}
