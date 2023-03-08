import CalloutHelpers from "./../helpers/callout_helpers";
import ConfirmationModal from "./../components/confirmation_modal";
import { Sortable } from "sortablejs";
import difference from "lodash/difference";
import union from "lodash/union";
import intersection from "lodash/intersection";
import DomElementHelpers from "../helpers/dom_element_helpers";

class EmbeddedObject {
	constructor(selector) {
		this.element = selector;
		this.parent = this.element.parentElement;
		this.$element = $(this.element);
		this.addButton = this.$element
			.siblings(".embedded-editor-header")
			.find("> .add-content-object")
			.first();
		this.page = 1;
		this.id = this.$element.prop("id");
		this.key = this.$element.data("key");
		this.label = this.$element.data("label");
		this.definition = this.$element.data("definition");
		this.options = this.$element.data("options");
		this.max = this.$element.data("max") || 0;
		this.min = this.$element.data("min") || 0;
		this.write =
			this.$element.data("write") !== undefined
				? this.$element.data("write")
				: true;
		this.total = this.$element.data("total") || 0;
		this.index = this.total;
		this.ids = this.$element.data("ids") || [];
		this.per = this.$element.data("per") || 5;
		this.url = this.$element.data("url");
		this.sortable;
		this.content_id = this.$element.data("content-id");
		this.content_type = this.$element.data("content-type");
		this.locationArray = location.hash.substr(1).split("+").filter(Boolean);
		this.eventHandlers = {
			import: this.import.bind(this),
			addItem: this.addNewItem.bind(this),
			removeItem: this.handleRemoveEvent.bind(this),
			scrollToLocationHash: this.scrollToLocationHash.bind(this),
		};
		this.addedItemsObserver = new MutationObserver(
			this.checkForAddedNodes.bind(this),
		);

		this.setup();
	}
	setup() {
		this.element.classList.add("dcjs-embedded-object");

		this.sortable = new Sortable(this.element, {
			forceAutoScrollFallback: true,
			scrollSpeed: 50,
			group: this.id,
			handle: ".draggable-handle",
			draggable: `.content-object-item.draggable_${this.id}`,
		});

		this.$element
			.off("dc:import:data", this.eventHandlers.import)
			.on("dc:import:data", this.eventHandlers.import)
			.addClass("dc-import-data");

		this.addEventHandlers();
		this.update();
		this.addedItemsObserver.observe(this.element, { childList: true });
	}
	setupContentObjectItem(element) {
		element
			.querySelector(this.selectorForRemoveContentObject())
			?.addEventListener("click", this.eventHandlers.removeItem);

		this.setupSwappableButtons(element);
	}
	runAddCallbacks(node) {
		if (node.querySelector(".content-object-item:not(.hidden)"))
			for (const e of node.querySelectorAll(
				".content-object-item:not(.hidden)",
			))
				this.setupContentObjectItem(e);

		if (node.matches(".content-object-item:not(.hidden)"))
			this.setupContentObjectItem(node);
	}
	checkForAddedNodes(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "childList") continue;

			for (const addedNode of mutation.addedNodes) {
				if (addedNode.nodeType === Node.ELEMENT_NODE)
					this.runAddCallbacks(addedNode);
			}
		}
	}
	locale() {
		return this.$element.data("locale") || "de";
	}
	async import(_event, data) {
		let newItems = difference(
			data.value,
			this.$element
				.children(".content-object-item")
				.map((_index, elem) => $(elem).data("id"))
				.get(),
		);

		if (
			this.write &&
			(this.max === 0 ||
				this.$element.children(".content-object-item").length < this.max) &&
			newItems.length > 0
		) {
			await this.renderEmbeddedObjects(
				"split_view",
				newItems,
				data.locale,
				data.translate,
			);
		} else if (
			this.write &&
			this.max !== 0 &&
			ids.length + newItems.length > this.max
		) {
			const prefix = await I18n.translate(
				"frontend.split_view.copy_linked_error",
			);

			new ConfirmationModal({
				text: `${this.label}: ${prefix}${await I18n.translate(
					"frontend.maximum_embedded",
					{
						data: this.max,
					},
				)}`,
			});
		}
	}
	selectorForEmbeddedHeader(selector) {
		return `:scope > .embedded-header > ${selector}, :scope > .form-element > .editor-block > .embedded-header > ${selector}`;
	}
	setSwapClasses(element) {
		if (element instanceof $) element = element[0];

		element
			.querySelector(this.selectorForEmbeddedHeader(".swap-button.swap-prev"))
			?.classList.toggle("disabled", !element.previousElementSibling);

		element
			.querySelector(this.selectorForEmbeddedHeader(".swap-button.swap-next"))
			?.classList.toggle("disabled", !element.nextElementSibling);
	}
	setupSwappableButtons(element) {
		if (
			!(
				element.matches(`.draggable_${this.id}`) &&
				element.querySelector(this.selectorForEmbeddedHeader(".swap-button"))
			)
		)
			return;

		for (const button of element.querySelectorAll(
			this.selectorForEmbeddedHeader(".swap-button"),
		))
			button.addEventListener("click", this.swapEmbedded.bind(this));
	}
	swapEmbedded(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const currentTarget = event.currentTarget;

		if (currentTarget.classList.contains("disabled")) return;

		const currentObject = currentTarget.closest(".content-object-item");

		if (currentTarget.classList.contains("swap-prev"))
			currentObject.previousElementSibling?.before(currentObject);
		else if (currentTarget.classList.contains("swap-next"))
			currentObject.nextElementSibling?.after(currentObject);

		this.update();

		DomElementHelpers.scrollIntoViewWithStickyOffset(currentObject);
	}
	renderEmbeddedObjects(type, ids = [], locale = null, translate = false) {
		let index = this.index;
		if (type === "split_view") this.index += difference(ids, this.ids).length;
		else if (type === "new") this.index++;

		this.parent.classList.add("loading-embedded");

		const promise = DataCycle.httpRequest(
			`${this.url}/render_embedded_object`,
			{
				method: "POST",
				body: {
					index: index,
					locale: this.locale(),
					attribute_locale: locale,
					key: this.key,
					definition: this.definition,
					options: this.options,
					content_id: this.content_id,
					content_type: this.content_type,
					object_ids: ids,
					duplicated_content: type === "split_view",
					translate: translate,
				},
			},
		);

		promise
			.then(this.insertNewElements.bind(this, ids))
			.catch(this.renderEmbeddedError.bind(this, translate))
			.finally(() => this.parent.classList.remove("loading-embedded"));

		return promise;
	}
	insertNewElements(ids, data) {
		const loadMore = this.element.querySelector(
			":scope > .load-more-linked-contents",
		);

		if (loadMore) loadMore.insertAdjacentHTML("beforebegin", data?.html);
		else this.element.insertAdjacentHTML("beforeend", data?.html);

		if (ids.length) this.ids = union(this.ids, ids);

		this.update();

		DomElementHelpers.scrollIntoViewWithStickyOffset(
			this.element.querySelector(":scope > .content-object-item:last-of-type"),
		);
	}
	async renderEmbeddedError(translate, error) {
		if (translate)
			CalloutHelpers.show(
				await I18n.translate("frontend.split_view.translate_error", {
					label: this.label,
				}),
				"alert",
			);
		else console.error(error);
	}
	selectorForRemoveContentObject(parent = "") {
		return `:scope ${parent} > .removeContentObject, :scope ${parent} > .form-element > .editor-block > .removeContentObject`;
	}
	addEventHandlers() {
		this.addButton
			.off("click", this.eventHandlers.addItem)
			.on("click", this.eventHandlers.addItem);

		if (
			this.element.querySelector(
				this.selectorForRemoveContentObject("> .content-object-item"),
			)
		)
			for (const button of this.element.querySelectorAll(
				this.selectorForRemoveContentObject("> .content-object-item"),
			))
				button.addEventListener("click", this.eventHandlers.removeItem);

		this.$element
			.off("init.zf.accordion", this.eventHandlers.scrollToLocationHash)
			.on("init.zf.accordion", this.eventHandlers.scrollToLocationHash);
	}
	async addNewItem(event) {
		event.preventDefault();
		event.stopPropagation();

		await this.renderEmbeddedObjects("new");

		this.$element.trigger("change");
	}
	handleRemoveEvent(event) {
		event.preventDefault();

		const element = $(event.currentTarget).closest(".content-object-item");

		if ($(event.currentTarget).data("confirm-delete") !== undefined) {
			new ConfirmationModal({
				text: $(event.currentTarget).data("confirm-delete"),
				confirmationClass: "alert",
				cancelable: true,
				confirmationCallback: () => {
					this.removeObject(element);
				},
			});
		} else this.removeObject(element);
	}
	removeObject(element) {
		let id = element.data("id");
		if (id !== undefined) {
			this.element
				.querySelector(`input[type="hidden"][value="${id}"]`)
				?.remove();
			this.ids = this.ids.filter((x) => x !== id);
		}

		element.remove();

		this.update();

		this.$element.trigger("change");
	}
	update() {
		const contentObjectItems = this.element.querySelectorAll(
			":scope > .content-object-item",
		);
		const removeButtons = this.element.querySelectorAll(
			this.selectorForRemoveContentObject("> .content-object-item"),
		);

		if (this.max && contentObjectItems.length >= this.max)
			this.addButton.hide();
		else if (this.write) this.addButton.show();

		if (this.min && contentObjectItems.length <= this.min)
			for (const button of removeButtons) button.style.display = "none";
		else if (this.write)
			for (const button of removeButtons)
				button.style.removeProperty("display");

		if (contentObjectItems.length === 0) {
			if (
				!this.element.querySelector(
					`:scope > input[type=hidden]#${this.id}_default`,
				)
			)
				this.element.insertAdjacentHTML(
					"beforeend",
					`<input type="hidden" value="" id="${this.id}_default" name="${this.key}[]">`,
				);
		} else
			this.element
				.querySelector(`:scope > input[type=hidden]#${this.id}_default`)
				?.remove();

		for (const child of contentObjectItems) this.setSwapClasses(child);

		this.updateContainerClass();
	}
	updateContainerClass() {
		this.element
			.closest(".form-element.embedded_object")
			.classList.toggle(
				"has-items",
				this.element.querySelector(":scope > .content-object-item"),
			);
	}
	scrollToLocationHash(event) {
		event.stopPropagation();

		if (!(this.locationArray?.length && this.ids?.length)) return;

		let embeddedId = intersection(this.locationArray, this.ids)[0];

		if (!embeddedId) return;

		let embeddedObject = this.$element
			.find(`.content-object-item[data-id="${embeddedId}"]`)
			.first();

		if (embeddedObject.hasClass("hidden")) this.loadAllContents(embeddedObject);
		else if (
			embeddedObject.data("accordion-item") &&
			!embeddedObject.hasClass("is-active")
		)
			embeddedObject
				.closest("[data-accordion]")
				.foundation("down", embeddedObject.find("> .accordion-content"));

		this.$element
			.find(
				"> .accordion-item:not(.is-active) > .accordion-content.remote-render",
			)
			.each((_index, item) => {
				let remoteOptions = $(item).data("remote-options");
				remoteOptions.hide_embedded = undefined;
				$(item).attr("data-remote-options", JSON.stringify(remoteOptions));
			});

		window.requestAnimationFrame(() => {
			DomElementHelpers.scrollIntoViewWithStickyOffset(embeddedObject[0]);
		});
	}
	loadAllContents(embeddedObject) {
		const observer = new MutationObserver((mutations) => {
			for (const mutation of mutations) {
				if (mutation.type !== "childList") continue;

				for (const addedNode of mutation.addedNodes) {
					if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;
					if (addedNode.dataset.id === embeddedObject[0].dataset.id) {
						observer.disconnect();

						$(addedNode.closest("[data-accordion]")).foundation(
							"down",
							$(addedNode).find("> .accordion-content"),
						);
					}
				}
			}
		});

		observer.observe(this.element, {
			subtree: true,
			childList: true,
		});

		this.element.querySelector(":scope > .load-more-linked-contents")?.click();
	}
}

export default EmbeddedObject;
