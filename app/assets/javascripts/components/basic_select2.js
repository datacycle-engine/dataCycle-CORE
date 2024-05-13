import Select2 from "select2";
import difference from "lodash/difference";
import i18nDe from "../helpers/select2_i18n_de";
import i18nEn from "../helpers/select2_i18n_en";
import Select2Helpers from "../helpers/select2_helpers";

class BasicSelect2 {
	constructor(element) {
		this.element = element;
		this.$element = $(this.element);
		this.query = {};
		this.config = this.$element.data() || {};
		this.defaultOptions = {
			allowClear: true,
			dropdownParent: this.$element.parent(),
			createTag: this.createTag.bind(this),
			selectionTitleAttribute: false,
			templateResult: this.templateResult.bind(this),
			templateSelection: this.templateSelection.bind(this),
		};
		this.select2Object = null;
		this.eventHandlers = {
			reset: this.reset.bind(this),
			import: this.import.bind(this),
			destroy: this.destroy.bind(this),
			suppressChange: this.suppressChangeEvent.bind(this),
			resizeDropdown: this.resizeDropdownEvent.bind(this),
			clear: this.clear.bind(this),
			setFocus: this.setFocus.bind(this),
		};
	}
	init() {
		this.$element[0].classList.add("dcjs-select2");

		if (!$.fn.select2) {
			Select2($);
			$.fn.select2.defaults.set("width", "100%");
			Select2Helpers.addselectionTitleAttributeOption($);

			switch (DataCycle.uiLocale) {
				case "de":
					$.fn.select2.defaults.set("language", i18nDe);
					break;
				case "en":
					$.fn.select2.defaults.set("language", i18nEn);
					break;
			}
		}

		this.initSelect2();
		this.initEventHandlers();
		this.initSpecificEventHandlers();
	}
	options() {
		return this.defaultOptions;
	}
	initSelect2() {
		this.$element.select2(this.options());
		this.select2Object = this.$element.data("select2");
	}
	initEventHandlers() {
		this.$element.closest("form").on("reset", this.eventHandlers.reset);
		this.$element
			.closest(".form-element")
			.on("dc:field:setToNull", this.eventHandlers.reset);
		this.$element
			.on("dc:import:data", this.eventHandlers.import)
			.addClass("dc-import-data");
		this.element.addEventListener("clear", this.eventHandlers.clear);
		this.$element.on("dc:select:destroy", this.eventHandlers.destroy);
		this.$element
			.parent()
			.on(
				"change",
				".select2-search__field",
				this.eventHandlers.suppressChange,
			);
		this.$element.on("change", this.eventHandlers.resizeDropdown);
		this.$element.on("select2:select", this.removeUnusedTags.bind(this));
		this.element.addEventListener("focus", this.eventHandlers.setFocus);
	}
	setFocus() {
		this.$element.select2("open");
	}
	removeUnusedTags(event) {
		if (
			this.select2Object.options.options.multiple ||
			!this.select2Object.options.options.tags ||
			event.params.data.newTag
		)
			return;

		for (const tag of this.$element
			.get(0)
			.querySelectorAll("option[data-select2-tag]"))
			tag.remove();
	}
	resizeDropdownEvent(_event) {
		const $dropdown = this.$element.closest(".dropdown-pane");

		if ($dropdown.length) $dropdown.trigger("dc:dropdown:resize");
	}
	suppressChangeEvent(event) {
		event.stopPropagation();
	}
	clear(_event) {
		if (this.element.querySelector(":scope > option")) {
			for (const option of this.element.querySelectorAll(":scope > option")) {
				option.selected = false;
			}
		}

		this.$element.trigger("change", { type: "reset" });
	}
	reset(_event) {
		if (this.element.querySelector(":scope > option")) {
			for (const option of this.element.querySelectorAll(":scope > option")) {
				option.selected = option.defaultSelected;
			}
		}

		this.$element.trigger("change", { type: "reset" });
	}
	destroy(_event) {
		this.$element.select2("destroy");
		this.$element.closest("form").off("reset", this.eventHandlers.reset);
		this.$element
			.off("dc:import:data", this.eventHandlers.import)
			.removeClass("dc-import-data");
		this.$element.off("dc:select:destroy", this.eventHandlers.destroy);
		this.$element
			.closest(".form-element")
			.off("dc:field:setToNull", this.eventHandlers.reset);
		this.$element
			.parent()
			.off(
				"change",
				".select2-search__field",
				this.eventHandlers.suppressChange,
			);
	}
	initSpecificEventHandlers() {}
	async import(_event, data) {
		if (!data.value?.length) return;

		let value = this.$element.val();
		if (!Array.isArray(value)) value = [value];
		if (!Array.isArray(data.value)) data.value = [data.value];

		value = value.filter(Boolean);
		data.value = data.value.filter(Boolean);
		const diff = difference(data.value, value);

		if (diff.length) await this.loadNewOptions(value, diff);
	}
	async loadNewOptions(_value, _options) {}
	markMatch(text, term) {
		const match = text.toLowerCase().lastIndexOf(term.toLowerCase());
		const $result = $("<span></span>");

		if (!term.length || match < 0) {
			return $result.html(text);
		}

		$result.html(text.substring(0, match));

		const $match = $('<span class="select2-highlight"></span>');
		$match.html(text.substring(match, match + term.length));

		$result.append($match);
		$result.append(text.substring(match + term.length));

		return $result;
	}
	addCollectionLinksToResults(data, container) {
		const htmlClass = this.getClassFromData(data);
		let linkType = null;

		if (htmlClass.includes("watch_list")) linkType = "watch_lists";
		else if (htmlClass.includes("stored_filter")) linkType = "search_history";

		if (linkType)
			$(container).append(
				`<a href="/${DataCycle.joinPath(
					DataCycle.config.EnginePath,
					linkType,
					data.id,
				)}" target="_blank" class="open-selection-link"><i class="fa fa-external-link" aria-hidden="true"></i></a>`,
			);
	}
	getClassFromData(data) {
		let htmlClass = "";

		if (data.html_class) htmlClass += data.html_class;
		else if (data.element) htmlClass += $(data.element).attr("class") || "";

		if (data.newTag) htmlClass += "new-tag";

		return htmlClass;
	}
	copySelect2Classes(data, container) {
		if (
			this.select2Object &&
			(container === undefined ||
				$(container).hasClass("select2-selection__rendered"))
		)
			this.select2Object.$selection
				.find(".select2-selection__rendered")
				.prop("class", "select2-selection__rendered");

		$(container).addClass(this.getClassFromData(data));
	}
	decorateResult(result) {
		$(result).html((_index, value) => {
			if (value !== undefined) {
				const text = value.split(" &gt; ");
				text[text.length - 1] = `<span class="select2-option-title">${
					text[text.length - 1]
				}</span>`;
				return text.join(" > ");
			}
		});
	}
	removeTreeLabel(result) {
		if (!this.config.treeLabel) return;

		$(result).html((_index, value) => {
			if (value !== undefined)
				return value.replace(`${this.config.treeLabel} &gt; `, "");
		});
	}
	copyDataAttributes(data, attributeTarget) {
		let source = data.element;
		let target = attributeTarget;

		if (source && source instanceof $) source = source[0];
		if (target instanceof $) target = target[0];
		if (!((source || data) && target)) return;

		if (source?.dataset.dcTooltip)
			target.dataset.dcTooltip = source.dataset.dcTooltip;
		else if (data.dc_tooltip) target.dataset.dcTooltip = data.dc_tooltip;

		target.classList.remove("dcjs-tooltip");

		if (source?.dataset.fullPath)
			target.dataset.fullPath = source.dataset.fullPath;
		else if (data.full_path) target.dataset.fullPath = data.full_path;
	}
	templateResult(data) {
		if (data.loading) return data.text;

		const term = this.query.term || "";
		const titleValue = data.element?.dataset.fullPath
			? data.element.dataset.fullPath
			: data.text;
		const result = titleValue ? this.markMatch(titleValue, term) : null;
		if (this.config.showTreeLabel !== "true") this.removeTreeLabel(result);
		this.decorateResult(result);
		this.copyDataAttributes(data, result);

		return result;
	}
	templateSelection(data) {
		data.selected = true;
		data.text = data.name || data.text;
		$(data.element).html(data.text);
		const $result = $(
			`<span class="selection-label-wrapper"><span class="selection-label">${data.text}</span></span>`,
		);
		this.copySelect2Classes(data, $result);
		this.addCollectionLinksToResults(data, $result);

		this.copyDataAttributes(data, $result);

		return $result;
	}
	removeTreeLabelFromSelection(text) {
		if (!this.config.treeLabel) return text;

		return text.replace(`${this.config.treeLabel} > `, "");
	}
	createTag(params) {
		const term = $.trim(params.term);

		if (term === "") {
			return null;
		}

		return {
			id: term,
			text: term,
			name: term,
			newTag: true,
		};
	}
}

export default BasicSelect2;
