import ClassificationNameButton from "../components/classification_administration/classification_name_button";
import ClassificationVisibilitySwitcher from "../components/classification_administration/classification_visibility_switcher";
import ClassificationLoadMoreButton from "../components/classification_administration/classification_load_more_button";
import ClassificationEditButton from "../components/classification_administration/classification_edit_button";
import ClassificationEditForm from "../components/classification_administration/classification_edit_form";
import ClassificationDestroyButton from "../components/classification_administration/classification_delete_button";
import ClassificationLoadAllButton from "../components/classification_administration/classification_load_all_button";
import ClassificationCloseAllButton from "../components/classification_administration/classification_close_all_button";
import ClassificationDragAndDrop from "../components/classification_administration/classification_drag_and_drop";
import ClassificationJumpToParent from "../components/classification_administration/classification_jump_to_parent";
import DetailToggler from "../components/detail_toggler";
import ClassificationUpdateChannel from "../components/classification_administration/classification_update_channel";

export default function () {
	if (document.getElementById("classification-administration")) {
		new ClassificationUpdateChannel();

		DataCycle.initNewElements(
			'input[name="classification_tree_label[visibility][]"][value^="show"]:not(.dcjs-classification-visibility-switcher)',
			(e) => new ClassificationVisibilitySwitcher(e),
		);

		DataCycle.initNewElements(
			"a.name:not(.dcjs-classification-name-button)",
			(e) => new ClassificationNameButton(e),
		);

		DataCycle.initNewElements(
			".load-more-button:not(.dcjs-classification-load-more-button)",
			(e) => new ClassificationLoadMoreButton(e),
		);

		DataCycle.initNewElements(
			"a.create:not(.dcjs-classification-edit-button), a.edit:not(.dcjs-classification-edit-button)",
			(e) => new ClassificationEditButton(e),
		);

		DataCycle.initNewElements(
			"form.classification-tree-label-form:not(.dcjs-classification-edit-form), form.classification-alias-form:not(.dcjs-classification-edit-form)",
			(e) => new ClassificationEditForm(e),
		);

		DataCycle.initNewElements(
			"a.destroy:not(.dcjs-classification-destroy-button)",
			(e) => new ClassificationDestroyButton(e),
		);

		DataCycle.initNewElements(
			".classification-load-all-children:not(.dcjs-classification-load-all-button)",
			(e) => new ClassificationLoadAllButton(e),
		);

		DataCycle.initNewElements(
			".classification-close-all-children:not(.dcjs-classification-load-all-button)",
			(e) => new ClassificationCloseAllButton(e),
		);

		DataCycle.initNewElements(
			".draggable-container:not(.dcjs-classification-drag-and-drop)",
			(e) => new ClassificationDragAndDrop(e),
		);

		DataCycle.initNewElements(
			"li.direct:not(.dcjs-classification-jump-to-parent), li.mapped:not(.dcjs-classification-jump-to-parent), li.new-button:not(.dcjs-classification-jump-to-parent)",
			(e) => new ClassificationJumpToParent(e),
		);
	}

	DataCycle.initNewElements(
		".toggle-details:not(.dcjs-detail-toggler)",
		(e) => new DetailToggler(e),
	);
}
