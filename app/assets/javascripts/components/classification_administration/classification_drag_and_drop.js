import { Sortable } from "sortablejs";
import CalloutHelpers from "../../helpers/callout_helpers";
import ConfirmationModal from "../confirmation_modal";
import { CancelSortPlugin } from "../sortable/cancel_sort_plugin";
Sortable.mount(CancelSortPlugin());

class ClassificationDragAndDrop {
	constructor(item) {
		this.item = item;
		this.treeLabel = this.item.closest("li.classification_tree_label");
		this.disableButton = this.treeLabel.querySelector(
			":scope > .inner-item > .classification-order-button",
		);
		this.mergeDropZone =
			this.item.parentElement.querySelector(".merge-dropzone");
		this.sortable = new Sortable(this.item, {
			forceAutoScrollFallback: true,
			scrollSpeed: 50,
			group: this.item.classList.contains("move-to-tree")
				? "draggable-classification-administration"
				: this.treeLabel.id,
			filter: "li.new-button, li.mapped",
			preventOnFilter: false,
			handle: ".draggable-handle",
			draggable: "li.direct, li.new-button, li.mapped",
			disabled: !this.treeLabel.classList.contains("sortable-active"),
			onEnd: this.onEnd.bind(this),
			onMove: this.checkNewButtonPosition.bind(this),
		});

		this.setup();
	}
	setup() {
		this.disableButton.addEventListener(
			"click",
			this.toggleSortable.bind(this),
		);

		this.addMergeHoverEvents();
	}
	addMergeHoverEvents() {
		if (this.mergeDropZone) {
			for (const type of ["dragenter", "dragover"])
				this.mergeDropZone.addEventListener(type, () => {
					this.mergeDropZone.classList.add("is-dragover");
				});

			for (const type of ["dragleave", "dragend", "drop"])
				this.mergeDropZone.addEventListener(type, () => {
					this.mergeDropZone.classList.remove("is-dragover");
				});
		}
	}
	toggleSortable(event) {
		event.preventDefault();

		if (this.sortable.option("disabled")) this.enableSortable();
		else this.disableSortable();
	}
	disableSortable() {
		this.treeLabel.classList.remove("sortable-active");
		this.sortable.option("disabled", true);
	}
	enableSortable() {
		this.treeLabel.classList.add("sortable-active");
		this.sortable.option("disabled", false);
	}
	onEnd(event) {
		const target = event.originalEvent.target;
		if (target instanceof Element && target.closest(".merge-dropzone")) {
			this.mergeWithElement(event, target.closest("li"));
			return;
		}

		this.updateOrder(event);
	}
	enableMoveElement(e) {
		e.classList.remove("saving-order");
	}
	disableMoveElement(e) {
		e.classList.add("saving-order");
	}
	enableMergeElements(source, target) {
		source.classList.remove("merging", "merge-source");
		target.classList.remove("merging", "merge-target");

		const nameTag = target.querySelector(":scope > .inner-item > a.name");

		if (!nameTag) return;

		nameTag.classList.remove("loaded");

		if (nameTag.classList.contains("open")) {
			requestAnimationFrame(() => {
				nameTag.click();
				requestAnimationFrame(() => nameTag.click());
			});
		}
	}
	disableMergeElements(source, target) {
		source.classList.add("merging", "merge-source");
		target.classList.add("merging", "merge-target");
	}
	revertMove(event) {
		this.sortable.cancelSort.revertDrag({
			dragEl: event.item,
			cloneEl: event.clone,
			...event,
		});
	}
	async mergeWithElement(event, target) {
		const source = event.item;

		this.revertMove(event);
		this.disableMergeElements(source, target);

		new ConfirmationModal({
			text: await I18n.translate(
				"classification_administration.merge.confirm_html",
				{
					source_path: source.querySelector(":scope > .inner-item > .name")
						?.dataset.dcTooltip,
					target_path: target.querySelector(":scope > .inner-item > .name")
						?.dataset.dcTooltip,
				},
			),
			confirmationClass: "alert",
			cancelable: true,
			confirmationCallback: () => {
				this.sendRequest(
					{
						sourceAliasId: source.dataset.id,
						targetAliasId: target.dataset.id,
					},
					"merge",
				)
					.then(this.renderResponseMessage.bind(this))
					.catch()

					.then((data) => {
						this.renderResponseMessage(data);
						this.enableMergeElements(source, target);
						source.remove();
					})
					.catch(() => {
						this.renderGeneralError("merge");
						this.enableMergeElements(source, target);
					});
			},
			cancelCallback: this.enableMergeElements.bind(this, source, target),
		});
	}
	async updateOrder(event) {
		if (event.from === event.to && event.oldIndex === event.newIndex) return;

		const element = event.item;
		this.disableMoveElement(element);

		if (event.from !== event.to) {
			new ConfirmationModal({
				text: await I18n.translate(
					"classification_administration.move.confirm_tree_label_id",
				),
				confirmationClass: "warning",
				cancelable: true,
				confirmationCallback: this.sendMoveRequest.bind(this, element),
				cancelCallback: () => {
					this.revertMove(event);
					this.enableMoveElement(element);
				},
			});
		} else this.sendMoveRequest(element);
	}
	sendMoveRequest(element) {
		this.sendRequest(
			{
				classificationAliasId: element.dataset.id,
				classificationTreeLabelId: element.closest(
					"li.classification_tree_label",
				).id,
				previousAliasId: element.previousElementSibling?.dataset.id,
				newParentAliasId:
					element.parentElement.closest("li.direct")?.dataset.id,
			},
			"move",
		)
			.then(this.renderResponseMessage.bind(this))
			.catch(this.renderGeneralError.bind(this, "move"))
			.finally(() => this.enableMoveElement(element));
	}
	renderResponseMessage(data) {
		if (data?.error) CalloutHelpers.show(data.error, "alert");
		if (data?.success) CalloutHelpers.show(data.success, "success");
	}
	async renderGeneralError(type) {
		I18n.t(`classification_administration.${type}.error`).then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
	sendRequest(data, type) {
		return DataCycle.httpRequest(`/classifications/${type}`, {
			method: "PATCH",
			body: data,
		});
	}
	checkNewButtonPosition(event) {
		if (
			event.originalEvent.target instanceof Element &&
			event.originalEvent.target.closest(".merge-dropzone")
		)
			return false;

		if (
			event.related.classList.contains("mapped") ||
			event.related.classList.contains("new-button")
		)
			return event.related.previousElementSibling &&
				!event.related.previousElementSibling.classList.contains("direct")
				? false
				: -1;

		return true;
	}
}

export default ClassificationDragAndDrop;
