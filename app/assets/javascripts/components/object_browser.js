import ConfirmationModal from "./../components/confirmation_modal";
import { Sortable } from "sortablejs";
import difference from "lodash/difference";
import union from "lodash/union";
import castArray from "lodash/castArray";
import loadingIcon from "../templates/loadingIcon";
import isEqual from "lodash/isEqual";
import sortBy from "lodash/sortBy";
import ObserverHelpers from "../helpers/observer_helpers";
import CalloutHelpers from "../helpers/callout_helpers";
import DomElementHelpers from "../helpers/dom_element_helpers";

class ObjectBrowser {
	constructor(selector) {
		this.element = selector;
		this.element.classList.add("dcjs-object-browser");
		this.$element = $(this.element);
		this.objectListElement = this.element.querySelector(
			":scope > .media-thumbs > .object-thumbs",
		);
		this.id = this.$element.prop("id");
		this.overlay = document.getElementById(`object_browser_${this.id}`);
		this.$overlay = $(`#object_browser_${this.id}`);
		this.label = $(`[for=${this.id}]`).text().trim();
		this.overlay_per = 25;
		this.per = this.$element.data("per") || 5;
		this.type = this.$element.data("type");
		this.locale = this.$element.data("locale");
		this.key = this.$element.data("key");
		this.hidden_field_id = this.$element.data("hidden-field-id");
		this.object_id = this.$element.data("object-id");
		this.object_key = this.$element.data("object-key");
		this.definition = this.$element.data("definition");
		this.options = this.$element.data("options");
		this.class = this.$element.data("class");
		this.templateName = this.$element.data("template-name");
		this.template = this.$element.data("template");
		this.max = this.$element.data("max");
		this.min = this.$element.data("min");
		this.limitedBy = this.$element.data("limited-by");
		this.index = this.per;
		this.editable = this.$element.data("editable");
		this.page = 1;
		this.loading = false;
		this.total = 0;
		this.ids = this.$element.data("objects") || [];
		this.chosen = this.ids.slice(0);
		this.preselectedItems = [];
		this.selected = "";
		this.excluded = [];
		this.sortable;
		this.content_id = this.$element.data("content-id");
		this.content_type = this.$element.data("content-type");
		this.prefix = this.$element.data("prefix");
		this.activeRequest;
		this.activeCountRequest;
		this.eventHandlers = {
			pageLeave: this.pageLeaveHandler.bind(this),
			submitWithoutRedirect: this.submitWithoutRedirectHandler.bind(this),
			setContentIds: this.setContentIdsHandler.bind(this),
			breadcrumbClick: this.breadcrumbClickHandler.bind(this),
			import: this.import.bind(this),
		};
		this.overlayInitObserver = new MutationObserver(
			this.initOverlay.bind(this),
		);
		this.changeObserver = new MutationObserver(
			this._checkForChangedFormData.bind(this),
		);
		this.itemsToHighlight = [];

		this.setup();
	}
	loadedIds() {
		return Array.from(
			this.objectListElement.querySelectorAll(":scope > li.item"),
		).map((e) => e.dataset.id);
	}
	setup() {
		this.sortable = new Sortable(
			this.$element.find("> .media-thumbs > .object-thumbs").get(0),
			{
				forceAutoScrollFallback: true,
				scrollSpeed: 50,
				handle: ".draggable-handle",
				draggable: "li.item",
			},
		);
		this.ids = difference(this.ids, this.loadedIds());

		this.overlayInitObserver.observe(this.overlay, {
			attributes: true,
			attributeFilter: ["class"],
		});
		this.$element.on(
			"click",
			".delete-thumbnail",
			this.clickDeleteThumbnailHandler.bind(this),
		);
		this.$element.on("dc:update:chosen", this.updateChosenHandler.bind(this));
		this.$element
			.on("dc:import:data", this.importDataHandler.bind(this))
			.addClass("dc-import-data");
		this.$overlay.on("open.zf.reveal", this.setOverlayPosition.bind(this));
		this.$overlay.on("closed.zf.reveal", this.resetOverlayPosition.bind(this));

		this.$element.on("dc:locale:changed", this.updateLocale.bind(this));
		this.$element.closest("form").on("reset", this.reset.bind(this));
		this.$element.on("clear", this.reset.bind(this));

		if (this.limitedBy === Object(this.limitedBy)) {
			let filterItem = this.$element.get(0);

			for (let i = 0; i < this.limitedBy.length; ++i) {
				if (!filterItem) continue;

				filterItem = filterItem[this.limitedBy[i][0]](this.limitedBy[i][1]);
			}

			this.limitedBy = $(filterItem);

			this.limitedBy.on("change", this.removeDeletedItem.bind(this));
			if (!this.$element.closest(".split-content.edit-content").length)
				this.removeDeletedItem();
		} else this.limitedBy = undefined;

		window.addEventListener("focus", this.highlightItems.bind(this));
	}
	_checkForChangedFormData(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "attributes") continue;

			if (
				mutation.target.classList.contains("remote-rendered") &&
				(!mutation.oldValue || mutation.oldValue.includes("remote-rendering"))
			)
				this.initNewFormHandlers();
		}
	}
	setOverlayPosition(_event) {
		if ($(".reveal:visible").not(this.$overlay).length)
			this.$overlay.addClass("full-height");
		else if (this.$overlay.data("overlay") === false)
			document.body.classList.add("object-browser-overlay-open");

		if ($(".breadcrumb ul li:last-child").data("object-browser-id") === this.id)
			return;

		// set breadcrumb link + text
		const text = $(".breadcrumb ul li:last-child").html();
		$(".breadcrumb ul li:last-child").html(
			`<a class="close-object-browser" href="#">${text}</a>`,
		);
		$(".breadcrumb ul").append(
			`<li data-object-browser-id="${
				this.id
			}"><span class="breadcrumb-text" title="${this.label.trim()} auswählen"><i><i class="fa fa-files-o" aria-hidden="true"></i>${this.label.trim()} auswählen</i></span></li>`,
		);
		$(".breadcrumb ul li").on(
			"click",
			".close-object-browser",
			this.eventHandlers.breadcrumbClick,
		);
	}
	resetOverlayPosition(_event) {
		this.$overlay.removeClass("full-height");

		if (
			!$(".reveal.object-browser-overlay:visible").not(this.$overlay).length &&
			this.$overlay.data("overlay") === false
		)
			document.body.classList.remove("object-browser-overlay-open");

		if ($(".breadcrumb ul li:last-child").data("object-browser-id") !== this.id)
			return;

		$(".breadcrumb ul li:last-child").remove();
		const text = $(
			".breadcrumb ul li:last-child a.close-object-browser",
		).html();
		$(".breadcrumb ul li:last-child").html(text);
		$(".breadcrumb ul li").off(
			"click",
			".close-object-browser",
			this.eventHandlers.breadcrumbClick,
		);
	}
	initOverlay(mutations) {
		if (mutations.some((e) => e.target.classList.contains("remote-rendered"))) {
			this.overlayInitObserver.disconnect();

			this.initOverlayHandlers();
		}
	}
	initOverlayHandlers(_element) {
		this.overlayFilter = this.$overlay.find(".object-browser-filter");
		this.overlayCount = this.overlayFilter.find(".item-count");
		this.overlayFilterForm = this.overlayFilter.find(
			".object-browser-filter-form",
		);
		this.overlayItemList = this.$overlay.children(".items");
		this.overlaySelectedList = this.overlay.querySelector(
			".chosen-items-container",
		);
		this.itemInfoScrollable = this.overlay.querySelector(
			".item-info-scrollable",
		);

		const newForm = document.querySelector(`#new_${this.id}.in-object-browser`);
		if (newForm?.querySelector("form")) this.initNewFormHandlers();
		else if (newForm?.querySelector(".new-content-form"))
			this.changeObserver.observe(
				newForm.querySelector(".new-content-form"),
				ObserverHelpers.changedClassConfig,
			);

		this.$overlay.on("open.zf.reveal", this.openOverlay.bind(this));
		this.$overlay.on("closed.zf.reveal", this.closeOverlay.bind(this));
		this.overlayFilterForm.on("submit", this.filterItems.bind(this));
		this.overlayFilterForm
			.find('.buttons button[type="reset"]')
			.on("click", this.resetFilter.bind(this));
		this.$overlay
			.find(".chosen-items-container")
			.on("click", "li.item", this.clickChosenItemsHandler.bind(this));
		this.overlayItemList.on(
			"click",
			"li.item",
			this.clickItemsHandler.bind(this),
		);
		this.$overlay
			.find(".chosen-items-container")
			.on(
				"click",
				".delete-thumbnail",
				this.clickChosenItemsDeleteHandler.bind(this),
			);
		this.$overlay
			.find(".buttons .save-object-browser")
			.on("click", this.clickSaveHandler.bind(this));
		this.$overlay.on(
			"dc:import:complete",
			this.importCompleteHandler.bind(this),
		);

		this.infiniteLoadingObserver = new IntersectionObserver(
			this.startInfiniteLoading.bind(this),
			{
				root: this.overlayItemList.get(0),
				rootMargin: "0px 0px 50px 0px",
				threshold: 0.1,
			},
		);

		this.$overlay.trigger("open.zf.reveal");
	}
	importCompleteHandler(event, data) {
		this.excluded = union(this.excluded, data?.ids);
		this.$overlay
			.children(".items")
			.find(`[data-id=${data.ids[0]}]`)
			.get(0)
			.scrollIntoView({
				behavior: "smooth",
			});

		for (const id of data.ids) {
			this.addObject(
				id,
				this.cloneHtml(this.$overlay.find(`[data-id=${id}]`)),
				event,
			);
		}

		$(`#new_${this.id}.in-object-browser form`).trigger("reset");
	}
	cloneHtml(html) {
		return DomElementHelpers.$cloneElement(html);
	}
	async importDataHandler(_event, data) {
		let newItems = [];
		let removedItems = [];

		if (data.external_ids !== undefined) newItems = data.external_ids;
		else if (data.value) {
			const existingIds = $.map(
				this.$element.find("> .media-thumbs > .object-thumbs > li.item"),
				(val, _i) => $(val).data("id"),
			);
			newItems = difference(data.value, existingIds);
			removedItems = difference(existingIds, data.value);
		}

		if (data.replace) {
			const query = removedItems.map(
				(r) => `> .media-thumbs > .object-thumbs > li.item[data-id="${r}"]`,
			);

			this.$element.find(query.join(", ")).each((_index, item) => {
				this.removeThumbObject(item, false);
			});
		}

		if (
			newItems.length > 0 &&
			(await this.validate(
				"+",
				this.chosen.length + newItems.length,
				I18n.translate("frontend.split_view.copy_linked_error"),
			))
		) {
			await this.findObjects(newItems, data.external_ids !== undefined);
		}
	}
	updateChosenHandler(_event, data) {
		this.chosen = union(this.chosen, data.chosen);
		this.updateHasItemsClass();
		this.updateChosenCounter();
	}
	async clickSaveHandler(event) {
		event.preventDefault();

		if (await this.validate()) {
			this.setChosen();
			this.$overlay.foundation("close");
			this.$element.closest(".form-element").trigger("change");
		}
	}
	clickChosenItemsDeleteHandler(event) {
		event.preventDefault();
		event.stopPropagation();

		const $target = $(event.currentTarget);

		this.removeObject($target.closest("li.item").data("id"), event);
	}
	async clickDeleteThumbnailHandler(event, data = {}) {
		event.preventDefault();
		event.stopPropagation();
		if (await this.validate("-", this.chosen.length - 1)) {
			this.removeThumbObject(event.target, !data.preventDefault);
		}
	}
	highlightItems(_event) {
		if (!this.itemsToHighlight.length) return;

		const highlightItemsClasses = this.itemsToHighlight
			.map((v) => `:scope > li.item[data-id="${v}"]`)
			.join(", ");
		const itemList = this.overlayItemList.get(0);

		if (itemList.querySelector(highlightItemsClasses))
			for (const item of itemList.querySelectorAll(highlightItemsClasses)) {
				item.classList.add("highlight");

				setTimeout(() => {
					item.classList.remove("highlight");
				}, 2000);
			}

		this.itemsToHighlight.length = 0;
	}
	clickItemsHandler(event) {
		const $target = $(event.currentTarget);
		const target = event.target;

		if (target.closest("a.show-link") || target.closest("a.edit-link")) {
			const liElement = target.closest("li.item");
			if (liElement) this.itemsToHighlight.push(liElement.dataset.id);

			return;
		}

		event.preventDefault();
		event.stopImmediatePropagation();

		if (this.selected !== $target.data("id")) {
			$target.addClass("in-object-browser");
			this.loadDetails($target.data("id"));
		}

		if (target.closest("a.show-sidebar-details")) return;

		if (this.chosen.indexOf($target.data("id")) === -1) {
			this.addObject($target.data("id"), this.cloneHtml($target), event);
		} else {
			this.removeObject($target.data("id"), event);
		}
	}
	clickChosenItemsHandler(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const $target = $(event.currentTarget);
		if (this.selected !== $target.data("id")) {
			this.loadDetails($target.data("id"));
		}
	}
	startInfiniteLoading(entries, _observer) {
		if (
			!entries[0].isIntersecting ||
			this.loading ||
			this.$overlay.children(".items").children("li.item").length >= this.total
		)
			return;

		this.infiniteLoadingObserver.disconnect();

		this.page += 1;
		this.loadObjects();
	}
	updateLocale(e) {
		e.stopPropagation();

		this.locale = this.element.dataset.locale;
	}
	submitWithoutRedirectHandler(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const formData = $(event.target).serializeJSON();
		$.extend(formData, {
			type: this.type,
			locale: this.locale,
			overlay_id: `#object_browser_${this.id}`,
			key: this.key,
			definition: this.definition,
			editable: this.editable,
			options: this.options,
			content_id: this.content_id,
			content_template_name: this.templateName,
			content_template: this.template,
			class: this.class,
			prefix: this.prefix,
			objects: this.chosen,
			new_overlay_id: `#new_${this.id}`,
		});

		DataCycle.httpRequest($(event.target).prop("action"), {
			method: "POST",
			body: formData,
		})
			.then(this.renderNewItems.bind(this))
			.catch(this.renderLoadError.bind(this));
	}
	setContentIdsHandler(event, data) {
		event.preventDefault();
		event.stopImmediatePropagation();

		if (!data?.contentIds?.length) return;

		DataCycle.httpRequest("/object_browser/render_in_overlay", {
			method: "POST",
			body: {
				ids: data.contentIds,
				type: this.type,
				locale: this.locale,
				overlay_id: `#object_browser_${this.id}`,
				key: this.key,
				definition: this.definition,
				editable: this.editable,
				options: this.options,
				content_id: this.content_id,
				content_template_name: this.templateName,
				content_template: this.template,
				class: this.class,
				prefix: this.prefix,
				objects: this.chosen,
				new_overlay_id: `#new_${this.id}`,
			},
		})
			.then(this.renderNewItems.bind(this))
			.catch(this.renderLoadError.bind(this));
	}
	renderDetailHtml(data) {
		if (data?.detail_html) this.itemInfoScrollable.innerHTML = data.detail_html;
	}
	renderNewItems(data) {
		if (data?.error) {
			CalloutHelpers.show(data.error, "alert");
			return;
		}
		if (data?.success) CalloutHelpers.show(data.success, "success");

		$(`#new_${this.id}`).foundation("close");

		if (data?.html) {
			this.overlay.querySelector(".items .no-results")?.remove();
			this.overlay
				.querySelector(".items .loading")
				?.insertAdjacentHTML("beforebegin", data.html);

			this.$overlay.trigger("dc:import:complete", { ids: data?.ids });
		}

		this.renderDetailHtml(data);
	}
	renderLoadError() {
		I18n.t("frontend.load_error").then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
	initNewFormHandlers(_e) {
		$(`#new_${this.id}.in-object-browser form`)
			.off(
				"dc:form:submitWithoutRedirect",
				this.eventHandlers.submitWithoutRedirect,
			)
			.on(
				"dc:form:submitWithoutRedirect",
				this.eventHandlers.submitWithoutRedirect,
			)
			.off("dc:form:setContentIds", this.eventHandlers.setContentIds)
			.on("dc:form:setContentIds", this.eventHandlers.setContentIds);
	}
	removeThumbObject(element, triggerChange = true) {
		let item;
		let elemId;

		if ($(element).is(':input[type="hidden"]')) {
			item = $(element);
			elemId = item.val();
		} else {
			item = $(element).closest("li.item");
			elemId = item.data("id");
		}

		this.chosen = difference(this.chosen, castArray(elemId));
		this.ids = difference(this.ids, castArray(elemId));
		this.$element.children(`input:hidden[value="${elemId}"]`).remove();
		this.updateHasItemsClass();
		item.remove();
		if (this.chosen.length === 0) this.renderHiddenField();
		if (triggerChange) {
			this.$element.trigger("dc:objectBrowser:change", {
				key: this.key,
				ids: this.chosen,
			});
			this.$element.closest(".form-element").trigger("change");
		}
	}
	renderHiddenField() {
		this.$element
			.find("> .media-thumbs > .object-thumbs")
			.html(
				`<input type="hidden" id="${this.hidden_field_id}" name="${this.key}[]">`,
			);
	}
	findObjects(ids, external) {
		const promise = DataCycle.httpRequest("/object_browser/find", {
			method: "POST",
			body: {
				type: this.type,
				locale: this.locale,
				key: this.key,
				prefix: this.prefix,
				definition: this.definition,
				options: this.options,
				ids: ids,
				editable: this.editable,
				class: this.class,
				content_id: this.content_id,
				content_type: this.content_type,
				content_template_name: this.templateName,
				content_template: this.template,
				objects: this.chosen,
				external: external,
			},
		});

		promise
			.then(this.renderFoundItems.bind(this))
			.catch(this.renderLoadError.bind(this));

		return promise;
	}
	renderFoundItems(data) {
		if (!(data?.html && data?.ids)) return;

		const ids = data.ids;
		const idSelector = ids
			.map((id) => `:scope > input[type="hidden"][value="${id}"]`)
			.join(", ");
		const lastHiddenItem = this.objectListElement.querySelector(
			`:scope > input[type="hidden"][value="${ids[ids.length - 1]}"]`,
		);

		if (lastHiddenItem) {
			lastHiddenItem.insertAdjacentHTML("afterend", data.html);
			for (const elem of this.objectListElement.querySelectorAll(idSelector))
				elem.remove();
		} else this.objectListElement.insertAdjacentHTML("beforeend", data.html);
		if (this.overlaySelectedList)
			this.overlaySelectedList.insertAdjacentHTML("beforeend", data.html);

		this.$element.trigger("dc:update:chosen", { chosen: ids });
	}
	async validate(
		type = "~",
		new_length = this.chosen.length,
		errorPrefix = "",
	) {
		if (type !== "-" && this.max !== 0 && new_length > this.max) {
			new ConfirmationModal({
				text: `${this.label}: ${await errorPrefix}${await I18n.translate(
					"frontend.maximum_embedded",
					{
						data: this.max,
					},
				)}`,
			});
			return false;
		}

		if (type !== "+" && this.min !== 0 && new_length < this.min) {
			new ConfirmationModal({
				text: `${this.label}: ${await errorPrefix}${await I18n.translate(
					"frontend.minimum_embedded",
					{
						data: this.min,
					},
				)}`,
			});
			return false;
		}
		return true;
	}
	updateHasItemsClass() {
		requestAnimationFrame(() => {
			this.objectListElement.classList.toggle(
				"has-items",
				this.objectListElement.querySelectorAll(
					':scope > li:not([type="hidden"])',
				).length > 0,
			);
		});
	}
	setChosen() {
		if (this.chosen.length === 0) {
			this.renderHiddenField();
		} else {
			this.$element
				.children(".media-thumbs")
				.children(".object-thumbs")
				.html(
					this.cloneHtml(this.$overlay.find(".chosen-items-container li.item")),
				);
		}

		this.updateHasItemsClass();

		this.$element.trigger("dc:objectBrowser:change", {
			key: this.key,
			ids: this.chosen,
		});
	}
	addObject(id, element, _event) {
		if (this.chosen.indexOf(id) === -1) {
			this.chosen.push(id);
			this.$overlay.find(".chosen-items-container").append(element);
			this.$overlay
				.children(".items")
				.find(`li.item[data-id=${id}]`)
				.addClass("active");
			this.updateChosenCounter();
		}
	}
	removeObject(id, _event) {
		this.chosen = difference(this.chosen, castArray(id));
		this.$element.children(`input:hidden[value="${id}"]`).remove();
		this.$overlay.find(`.chosen-items-container [data-id=${id}]`).remove();
		this.$overlay
			.children(".items")
			.find(`li.item[data-id=${id}]`)
			.removeClass("active");
		this.updateHasItemsClass();
		this.updateChosenCounter();
	}
	updateChosenCounter() {
		let html = "";
		if (this.chosen.length > 1)
			html = `<strong>${this.chosen.length}</strong> Elemente auswählen`;
		else if (this.chosen.length === 1)
			html = `<strong>${this.chosen.length}</strong> Element auswählen`;
		else html = "Keine Elemente auswählen";
		this.$overlay.find(".chosen-counter").html(html);
	}
	loadMore(_loaded_ids) {
		const promise = DataCycle.httpRequest(
			`/things/${this.content_id}/load_more_linked_objects`,
			{
				method: "POST",
				body: {
					key: this.object_key,
					complete_key: this.key,
					locale: this.locale,
					definition: this.definition,
					options: this.options,
					class: this.class,
					editable: this.editable,
					content_id: this.content_id,
					content_type: this.content_type,
					load_more_action: "object_browser",
					load_more_type: "all",
					load_more_except: undefined,
				},
			},
		);

		promise
			.then(this.renderFoundItems.bind(this))
			.then(() => {
				this.objectListElement
					.querySelector(".load-more-linked-contents")
					?.parentElement.remove();
				this.ids.length = 0;
				this.loadObjects(false);
			})
			.catch(this.renderLoadError.bind(this));

		return promise;
	}
	loadDetails(id) {
		this.selected = id;
		DataCycle.httpRequest("/object_browser/details", {
			method: "POST",
			body: {
				type: this.type,
				locale: this.locale,
				key: this.key,
				prefix: this.prefix,
				definition: this.definition,
				options: this.options,
				class: this.class,
				id: id,
			},
		})
			.then(this.renderDetailHtml.bind(this))
			.catch(this.renderLoadError.bind(this));
	}
	resetOverlay() {
		this.overlayFilterForm.get(0).reset();
		this.$overlay.find(".chosen-items-container li.item").remove();
		this.chosen = [];
		this.excluded = [];
		this.page = 1;
	}
	reset(_event) {
		this.$element.find(".media-thumbs li.item").each((_, element) => {
			this.removeThumbObject(element, false);
		});
	}
	setPreselected() {
		this.$overlay
			.find(".chosen-items-container")
			.html(
				this.cloneHtml(
					this.$element.find("> .media-thumbs > .object-thumbs > li.item"),
				),
			);
		this.chosen = $.map(
			this.$element.find("> .media-thumbs > .object-thumbs > li.item"),
			(val, i) => $(val).data("id"),
		);
	}
	openOverlay(_ev) {
		this.overlayCount.html("");
		this.preselectedItems = this.chosen.slice(0);
		$(window).on("beforeunload", this.eventHandlers.pageLeave);
		this.resetOverlay();
		this.setPreselected();
		this.updateChosenCounter();

		$(window).on(
			"message.object_browser onmessage.object_browser",
			this.eventHandlers.import,
		);
		const loaded = $.map(
			this.$element.find("> .media-thumbs > .object-thumbs > li.item"),
			(val, i) => $(val).data("id"),
		);
		if (difference(this.ids, loaded).length) this.loadMore(loaded);
		else this.loadObjects(false);
	}
	closeOverlay(_ev) {
		$(window).off("beforeunload", this.eventHandlers.pageLeave);
		$(window).off(
			"message.object_browser onmessage.object_browser",
			this.eventHandlers.import,
		);
		$("#asset-upload-reveal-default").off("closed.zf.reveal");
	}
	breadcrumbClickHandler(event) {
		event.preventDefault();

		this.$overlay.foundation("close");
	}
	pageLeaveHandler(e) {
		if (!isEqual(sortBy(this.preselectedItems), sortBy(this.chosen))) {
			e.preventDefault();
			e.returnValue = "";

			return e.returnValue;
		}
	}
	// import media from media_archive reveal
	import(event) {
		if (event.originalEvent?.data?.action === "import") {
			const promise = DataCycle.httpRequest("/things/import", {
				method: "POST",
				body: {
					type: `${this.type}_object`,
					data: event.originalEvent.data.data,
					locale: this.locale,
					key: this.key,
					prefix: this.prefix,
					definition: this.definition,
					options: this.options,
					editable: this.editable,
					objects: this.chosen,
				},
			});
			promise
				.then(this.renderNewItems.bind(this))
				.catch(this.renderLoadError.bind(this));

			return promise;
		}
	}
	filterItems(event = null) {
		if (event) {
			event.preventDefault();
			event.stopImmediatePropagation();
		}

		this.page = 1;
		this.loadObjects(false);
	}
	resetFilter(event = null, triggerReload = true) {
		if (event) event.preventDefault();

		this.overlayFilterForm.get(0).reset();

		if (triggerReload) this.filterItems();
	}
	serializeFilter() {
		return this.overlayFilterForm.serializeJSON();
	}
	showParams() {
		return {
			page: this.page,
			per: this.overlay_per,
			type: this.type,
			locale: this.locale,
			key: this.key,
			definition: this.definition,
			options: this.options,
			filter: this.serializeFilter(),
			objects: this.chosen,
			editable: this.editable,
			excluded: this.excluded,
			content_id: this.content_id,
			content_type: this.content_type,
			content_template_name: this.templateName,
			content_template: this.template,
			prefix: this.prefix,
			filter_ids: this.filteredIds(),
		};
	}
	loadCount() {
		this.overlayCount.html(loadingIcon());

		const promise = DataCycle.httpRequest("/object_browser/show", {
			method: "POST",
			body: Object.assign(this.showParams(), { count_only: true }),
		});

		this.activeCountRequest = promise;

		promise.then(async (data) => {
			if (this.activeCountRequest !== promise || !data) return;

			const count = data.count || 0;
			this.total = count;
			this.$overlay.data("total", count);

			I18n.translate("common.things_count_html", {
				count: count,
				delimited_count: count.toLocaleString("de-DE"),
			}).then((countText) => {
				this.overlayCount.html(countText);
			});
		});
	}
	loadObjects(append = true) {
		this.infiniteLoadingObserver.disconnect();

		if (!append) {
			this.excluded = [];
			this.$overlay.children(".items").scrollTop(0);
			this.$overlay.children(".items").html(loadingIcon());
			this.loadCount();
		}
		this.$overlay.find(".items .loading").show();
		this.loading = true;

		const promise = DataCycle.httpRequest("/object_browser/show", {
			method: "POST",
			body: Object.assign(this.showParams(), { append: append }),
		});

		this.activeRequest = promise;

		promise.then(async (data) => {
			if (this.activeRequest !== promise || !data) return;

			this.$overlay.find(".items .loading").hide();

			let html = data.html;
			if (!data.has_contents)
				html = `<span class="no-results">${await I18n.translate(
					"common.no_results",
				)}</span>`;
			$(html).insertBefore(this.$overlay.find(".items .loading"));

			this.loading = false;

			if (!data.last_page && data.has_contents)
				this.infiniteLoadingObserver.observe(
					this.$overlay.children(".items").children("li.item").last().get(0),
				);
		});

		return promise;
	}
	removeDeletedItem() {
		if (!this.chosen.length) return;

		const toRemove = difference(this.chosen, this.filteredIds());
		if (toRemove.length) {
			for (const item of toRemove) {
				this.removeThumbObject(
					this.$element.find(
						`> .media-thumbs > .object-thumbs > li.item[data-id="${item}"], > .media-thumbs > .object-thumbs > :input[value="${item}"]`,
					),
				);
			}
		}
	}
	filteredIds() {
		if (this.limitedBy === undefined) return [];

		return this.limitedBy
			.find("> .object-browser input:hidden")
			.map((_, item) => $(item).val())
			.get();
	}
}

export default ObjectBrowser;
