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

		DataCycle.registerAddCallback(
			'input[name="classification_tree_label[visibility][]"][value^="show"]',
			"classification-visibility-switcher",
			(e) => new ClassificationVisibilitySwitcher(e),
		);

		DataCycle.registerAddCallback(
			"a.name",
			"classification-name-button",
			(e) => new ClassificationNameButton(e),
		);

		DataCycle.registerAddCallback(
			".load-more-button",
			"classification-load-more-button",
			(e) => new ClassificationLoadMoreButton(e),
		);

		DataCycle.registerAddCallback(
			"a.create, a.edit",
			"classification-edit-button",
			(e) => new ClassificationEditButton(e),
		);

		DataCycle.registerAddCallback(
			"form.classification-tree-label-form, form.classification-alias-form",
			"classification-edit-form",
			(e) => new ClassificationEditForm(e),
		);

		DataCycle.registerAddCallback(
			"a.destroy",
			"classification-destroy-button",
			(e) => new ClassificationDestroyButton(e),
		);

		DataCycle.registerAddCallback(
			".classification-load-all-children",
			"classification-load-all-button",
			(e) => new ClassificationLoadAllButton(e),
		);

		DataCycle.registerAddCallback(
			".classification-close-all-children",
			"classification-load-all-button",
			(e) => new ClassificationCloseAllButton(e),
		);

		DataCycle.registerAddCallback(
			".draggable-container",
			"classification-drag-and-drop",
			(e) => new ClassificationDragAndDrop(e),
		);

		DataCycle.registerAddCallback(
			"li.direct, li.mapped, li.new-button",
			"classification-jump-to-parent",
			(e) => new ClassificationJumpToParent(e),
		);
	}

	DataCycle.registerAddCallback(
		".toggle-details",
		"detail-toggler",
		(e) => new DetailToggler(e),
	);
}
