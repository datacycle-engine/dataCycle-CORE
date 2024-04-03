import CalloutHelpers from "./../helpers/callout_helpers";
import ConfirmationModal from "./../components/confirmation_modal";
import { Sortable } from "sortablejs";
import difference from "lodash/difference";
import intersection from "lodash/intersection";
import ObserverHelpers from "../helpers/observer_helpers";
import DcStickyBar from "./dc_sticky_bar";

class EmbeddedObject {
	constructor(selector) {
		this.element = selector;
		this.parent = this.element.parentElement;
		this.$element = $(this.element);
		this.addButtonWrapper = this.parent.querySelector(
			":scope > .embedded-editor-header .new-embedded-button-wrapper",
		);
		this.addButtons = this.parent.querySelectorAll(
			":scope > .embedded-editor-header .new-embedded-button-wrapper .add-content-object",
		);
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
		this.templateName = this.$element.data("template-name");
		this.template = this.$element.data("template");
		this.locationArray = location.hash.substr(1).split("+").filter(Boolean);
		this.eventHandlers = {
			import: this.import.bind(this),
			addItem: this.addNewItem.bind(this),
			removeItem: this.handleRemoveEvent.bind(this),
			scrollToLocationHash: this.scrollToLocationHash.bind(this),
			clear: this.clear.bind(this),
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
			onChange: this.update.bind(this),
		});

		this.$element
			.off("dc:import:data", this.eventHandlers.import)
			.on("dc:import:data", this.eventHandlers.import)
			.addClass("dc-import-data");

		this.element.removeEventListener("clear", this.eventHandlers.clear);
		this.element.addEventListener("clear", this.eventHandlers.clear);

		this.addEventHandlers();
		this.update();
		this.addedItemsObserver.observe(this.element, { childList: true });
	}
	setupContentObjectItem(element) {
		element.classList.add("dcjs-coi");

		element
			.querySelector(this.selectorForRemoveContentObject())
			?.addEventListener("click", this.eventHandlers.removeItem);

		this.setupSwappableButtons(element);
	}
	runAddCallbacks(node) {
		ObserverHelpers.checkForConditionRecursive(
			node,
			".content-object-item:not(.hidden):not(.dcjs-coi)",
			this.setupContentObjectItem.bind(this),
		);
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
		return this.element.dataset.locale || "de";
	}
	import(_event, data) {
		const newItems = difference(
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
			return this.renderEmbeddedObjects(
				"split_view",
				newItems,
				data.locale,
				data.translate,
			);
		}

		if (
			this.write &&
			this.max !== 0 &&
			ids.length + newItems.length > this.max
		) {
			return I18n.translate("frontend.split_view.copy_linked_error").then(
				(prefix) =>
					I18n.translate("frontend.maximum_embedded", {
						data: this.max,
					}).then(
						(text) =>
							new ConfirmationModal({
								text: `${this.label}: ${prefix}${text}`,
							}),
					),
			);
		}
	}
	selectorForEmbeddedHeader(selector) {
		return `:scope > .embedded-header > ${selector}, :scope > .form-element > .editor-block > .embedded-header > ${selector}`;
	}
	setSwapClasses(element) {
		let elem = element;
		if (elem instanceof $) elem = elem[0];

		elem
			.querySelector(this.selectorForEmbeddedHeader(".swap-button.swap-prev"))
			?.classList.toggle("disabled", !elem.previousElementSibling);

		elem
			.querySelector(this.selectorForEmbeddedHeader(".swap-button.swap-next"))
			?.classList.toggle("disabled", !elem.nextElementSibling);
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

		DcStickyBar.scrollIntoViewWithStickyOffset(currentObject);
	}
	renderEmbeddedObjects(
		type,
		ids = [],
		locale = null,
		translate = false,
		specificEmbeddedTemplate = "",
	) {
		const index = this.index;
		const newIds = difference(ids, this.ids);
		if (type === "split_view") this.index += newIds.length;
		else if (type === "new") this.index++;

		this.parent.classList.add("loading-embedded");
		this.ids.push(...newIds);

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
					content_template_name: this.templateName,
					content_template: this.template,
					object_ids: newIds,
					duplicated_content: type === "split_view",
					translate: translate,
					embedded_template: specificEmbeddedTemplate,
				},
			},
		);

		promise
			.then(this.insertNewElements.bind(this, newIds))
			.catch(this.renderEmbeddedError.bind(this, newIds, translate))
			.finally(() => this.parent.classList.remove("loading-embedded"));

		return promise;
	}
	insertNewElements(ids, data) {
		const loadMore = this.element.querySelector(
			":scope > .load-more-linked-contents",
		);
		let insertAfterElement;
		const activeIndex = this.ids.indexOf(ids[0]);

		if (activeIndex >= 0) {
			const selector = this.ids
				.slice(0, activeIndex)
				.map((id) => `:scope > [data-id="${id}"]`)
				.join(", ");

			if (selector && this.element.querySelector(selector)) {
				const previousElements = this.element.querySelectorAll(selector);
				insertAfterElement = previousElements[previousElements.length - 1];
			}
		}

		if (insertAfterElement) {
			insertAfterElement.insertAdjacentHTML("afterend", data?.html);
		} else if (loadMore) loadMore.insertAdjacentHTML("beforebegin", data?.html);
		else this.element.insertAdjacentHTML("beforeend", data?.html);

		this.update();

		DcStickyBar.scrollIntoViewWithStickyOffset(
			this.element.querySelector(":scope > .content-object-item:last-of-type"),
		);
	}
	async renderEmbeddedError(ids, translate, error) {
		this.ids = difference(this.ids, ids);

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
		for (const button of this.addButtons) {
			button.removeEventListener("click", this.eventHandlers.addItem);
			button.addEventListener("click", this.eventHandlers.addItem);
		}

		this.runAddCallbacks(this.element);

		this.$element
			.off("init.zf.accordion", this.eventHandlers.scrollToLocationHash)
			.on("init.zf.accordion", this.eventHandlers.scrollToLocationHash);
	}
	async addNewItem(event) {
		event.preventDefault();
		event.stopPropagation();

		const currentElement = event.currentTarget;
		const templateName = currentElement.dataset.template;
		if (currentElement.classList.contains("in-dropdown")) {
			const $dropdown = $(
				currentElement.closest(".new-embedded-object.dropdown-pane"),
			);
			if (typeof $dropdown.foundation === "function")
				$dropdown.foundation("close");
		}

		await this.renderEmbeddedObjects("new", [], null, null, templateName);

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
		const id = element.data("id");
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
			this.addButtonWrapper.style.display = "none";
		else if (this.write) this.addButtonWrapper.style.removeProperty("display");

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

		const embeddedId = intersection(this.locationArray, this.ids)[0];

		if (!embeddedId) return;

		const embeddedObject = this.$element
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
				const remoteOptions = $(item).data("remote-options");
				remoteOptions.hide_embedded = undefined;
				$(item).attr("data-remote-options", JSON.stringify(remoteOptions));
			});

		window.requestAnimationFrame(() => {
			DcStickyBar.scrollIntoViewWithStickyOffset(embeddedObject[0]);
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
	clear(_event) {
		const selector = ":scope > .content-object-item";

		if (this.element.querySelector(selector))
			for (const element of this.element.querySelectorAll(selector))
				this.removeObject($(element));
	}
}

export default EmbeddedObject;
