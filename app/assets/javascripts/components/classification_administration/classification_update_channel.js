class ClassificationUpdateChannel {
	constructor() {
		this.container = document.querySelector(
			"ul.classification_trees.backend-treeview-list",
		);

		this.setup();
	}
	setup() {
		this.initActionCable();
	}
	initActionCable() {
		window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::ClassificationUpdateChannel",
			},
			{
				received: (data) => {
					if (data.type === "error") {
						return I18n.t(
							"controllers.error.classification_mappings_error",
						).then((t) => CalloutHelpers.show(t, "alert"));
					}

					if (data.type === "lock") this.addWarningAndLock(data.id);
					else if (data.type === "unlock") this.removeWarningAndUnlock(data.id);
				},
			},
		);
	}
	async warningHtml() {
		return `<i class="fa fa-exclamation-triangle warning-color classification-mappings-queued" data-dc-tooltip="${await I18n.t(
			"controllers.success.classification_mappings_queued",
		)}"></i>`;
	}
	async addWarningAndLock(id) {
		const liElement = this.container.querySelector(
			`li.direct[data-id="${id}"]`,
		);

		if (!liElement) return;

		const select = liElement.querySelector(
			".classification-ids-field > select",
		);
		const html = await this.warningHtml();
		const queuedSelector =
			":scope > .inner-item > .classification-mappings-queued";

		if (!liElement.querySelector(queuedSelector))
			liElement
				.querySelector(":scope > .inner-item")
				?.insertAdjacentHTML("beforeend", html);

		if (select) {
			select.disabled = true;

			const selectQueuedSelector =
				".classification-ids-field > label > .classification-mappings-queued";

			if (!liElement.querySelector(selectQueuedSelector))
				liElement
					.querySelector(".classification-ids-field > label")
					?.insertAdjacentHTML("beforeend", html);
		}

		const hiddenFieldSelector =
			'input[type="hidden"][name="classification_alias[classification_ids][]"]';
		if (liElement.querySelector(hiddenFieldSelector))
			for (const field of liElement.querySelectorAll(hiddenFieldSelector))
				field.remove();
	}
	removeWarningAndUnlock(id) {
		const liElement = this.container.querySelector(
			`li.direct[data-id="${id}"]`,
		);

		if (!liElement) return;

		const form = liElement.querySelector(
			".classification-alias-form-container",
		);
		if (form) $(form).trigger("dc:remote:reloadOnNextOpen");

		liElement
			.querySelector(":scope > .inner-item > i.classification-mappings-queued")
			?.remove();
		const nameTag = liElement.querySelector(":scope > .inner-item > a.name");
		const open = nameTag?.classList?.contains("open");
		if (nameTag) nameTag.classList.remove("loaded");
		if (open) nameTag.click();
		if (nameTag) nameTag.classList.remove("loaded");
		if (open) nameTag.click();
	}
}

export default ClassificationUpdateChannel;
