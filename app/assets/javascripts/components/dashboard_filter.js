import DomElementHelpers from "../helpers/dom_element_helpers";

class DashboardFilter {
	constructor(element) {
		this.$searchForm = $(element);
		this.$defaultFilterContainer = this.$searchForm
			.find(".main-filters")
			.first();
		this.$classificationTreeFilterContainer = this.$searchForm
			.find(".classification-tree-filter")
			.first();
		this.$advancedFilterContainer = this.$searchForm.find(
			".advanced-filters, .permanent-advanced-filters",
		);
		this.$addAdvancedFilterSelect = this.$advancedFilterContainer
			.find("#add_advanced_filter")
			.first();
		this.$searchInput = this.$searchForm
			.find("input.fulltext-search-field")
			.first();
		this.$clickableMenus = this.$searchForm.find(".clickable-menu");
		this.$primaryClickableMenu =
			this.$defaultFilterContainer.find(".clickable-menu");
		this.$filterTagsContainer = this.$searchForm.find(".filtertags").first();
		this.$languageSelectContainer = this.$searchForm
			.find(".clickable-menu.language-filter")
			.first();
		this.$languageTags = this.$searchForm
			.find(".languagetags .tags-container")
			.first();
		this.categoryFilterHeights = [];
		this.addFilterPath = this.$searchForm.data("addFilterPath");
		this.addTagGroupPath = this.$searchForm.data("addTagGroupPath");
		this.$sortableTypeSelect = this.$searchForm
			.find(".mode-container .filter-sortable select")
			.first();
		this.$sortableOrderInputs = this.$searchForm.find(
			".mode-container .filter-sortable .filter-sortable-checkbox-wrapper :input",
		);
		this.defaultFilterOptions = {
			splitListClass: "split-list",
			numCols: 4,
			listItem: "li",
			listClass: "sub-list",
		};
		this.leaveDebounceTimer = null;

		this.setup();
	}
	setup() {
		this.initDefaultFilters();
		this.initEventHandlers();
		this.initSearchForm();
		this.initClickableMenu();

		this.$searchForm[0].dataset.initialFormData = JSON.stringify(
			Array.from(new FormData(this.$searchForm[0])),
		);
		this.$searchForm[0].classList.add("dcjs-dashboard-filter");
	}
	initDefaultFilters() {
		if (!this.$defaultFilterContainer.length) return;

		this.$defaultFilterContainer
			.find(`.${this.defaultFilterOptions.splitListClass}`)
			.each((_, elem) => {
				const itemsPerCol = new Array();
				const items = $(elem).find(this.defaultFilterOptions.listItem);
				const minItemsPerCol = Math.floor(
					items.length / this.defaultFilterOptions.numCols,
				);
				const difference =
					items.length - minItemsPerCol * this.defaultFilterOptions.numCols;
				for (let i = 0; i < this.defaultFilterOptions.numCols; i++) {
					if (i < difference) {
						itemsPerCol[i] = minItemsPerCol + 1;
					} else {
						itemsPerCol[i] = minItemsPerCol;
					}
				}
				for (let i = 0; i < this.defaultFilterOptions.numCols; i++) {
					$(elem).append(
						$("<ul ></ul>").addClass(this.defaultFilterOptions.listClass),
					);
					for (let j = 0; j < itemsPerCol[i]; j++) {
						let pointer = 0;
						for (let k = 0; k < i; k++) {
							pointer += itemsPerCol[k];
						}
						$(elem)
							.find(`.${this.defaultFilterOptions.listClass}`)
							.last()
							.append(items[j + pointer]);
					}
				}
			});
	}
	initEventHandlers() {
		this.$defaultFilterContainer.on(
			"change",
			".filter ul :checkbox",
			this.markDefaultFilterAsChecked.bind(this),
		);
		this.$classificationTreeFilterContainer.on(
			"change",
			"ul :checkbox",
			this.markDefaultFilterAsChecked.bind(this),
		);
		if (this.$languageSelectContainer.length)
			this.$languageSelectContainer.on(
				"change",
				".filter ul :checkbox",
				this.toggleLanguages.bind(this),
			);

		this.$advancedFilterContainer.on(
			"change",
			".advanced-filter",
			this.advancedFilterChange.bind(this),
		);
		this.$advancedFilterContainer.on(
			"change",
			".advanced-filter.conditional-value-selector .advanced-filter-mode select",
			this._conditionalValueSelectorChange.bind(this),
		);
		this.$addAdvancedFilterSelect.on(
			"change",
			this.addAdvancedFilter.bind(this),
		);
		this.$advancedFilterContainer.on(
			"click",
			".remove-advanced-filter",
			this.removeAdvancedFilter.bind(this),
		);
		this.$filterTagsContainer.on(
			"click",
			".remove-advanced-filter",
			this.removeAdvancedFilter.bind(this),
		);
		this.$filterTagsContainer.on(
			"click",
			".remove-hidden-filter",
			this.removeHiddenFilter.bind(this),
		);
		this.$filterTagsContainer.on(
			"click",
			".focus-advanced-filter",
			this.focusAdvancedFilter.bind(this),
		);
		this.$sortableTypeSelect.on(
			"change",
			this.toggleSortableOrderEditability.bind(this),
		);
		this.$sortableOrderInputs.on("change", this.triggerSearch.bind(this));
	}
	toggleSortableOrderEditability(_event) {
		this.$sortableOrderInputs.prop("disabled", !this.$sortableTypeSelect.val());
		this.triggerSearch();
	}
	toggleLanguages(event) {
		event.preventDefault();
		event.stopPropagation();

		this.languageHandler(
			$(event.currentTarget),
			$(event.currentTarget).is(":checked"),
		);
		this.markDefaultFilterAsChecked(event);
	}
	markDefaultFilterAsChecked(event) {
		event.preventDefault();
		event.stopPropagation();

		const $parent = $(event.currentTarget).closest(".filter");
		const value = $parent.find(":input").serializeJSON();
		if (!Object.keys(value).length) value[$parent.data("id")] = null;

		this.addTagGroup(value);
	}
	defaultFilterMouseEnter(event) {
		const childList = $(event.currentTarget).find("ul").first();
		if (
			childList.length &&
			Math.round($(".off-canvas-wrapper").outerHeight()) <
				Math.round(childList.outerHeight() + childList.offset().top + 150)
		) {
			$(".off-canvas-wrapper").css(
				"height",
				childList.outerHeight() + childList.offset().top + 150,
			);
		}

		this.categoryFilterHeights.push(
			$(event.currentTarget).find("ul").height() || 0,
		);
		const height = Math.max.apply(null, this.categoryFilterHeights);
		$(event.currentTarget)
			.parentsUntil("#primary_nav_wrap")
			.find("ul:visible")
			.each((_, elem) => {
				$(elem).css("min-height", height);
			});
	}
	defaultFilterMouseLeave(event) {
		this.categoryFilterHeights.pop();
		const height = Math.max.apply(null, this.categoryFilterHeights);
		$(event.currentTarget)
			.parentsUntil("#primary_nav_wrap")
			.find("ul:visible")
			.each((_, elem) => {
				$(elem).css("min-height", height);
			});
	}
	switchAdvancedAttributesInput(elem) {
		const newTarget = $(elem).find("> .advanced-filter-selector");
		const selectValue = $(elem).find("> .advanced-filter-mode select").val();

		if (selectValue === "b" || selectValue === "p") {
			newTarget
				.find(":input[type=hidden]:not(.flatpickr-input)")
				.prop("disabled", false);
			newTarget
				.find(":input:not([type=hidden]), :input[type=hidden].flatpickr-input")
				.prop("disabled", true);
		} else {
			newTarget
				.find(":input[type=hidden]:not(.flatpickr-input)")
				.prop("disabled", true);
			newTarget
				.find(":input:not([type=hidden]), :input[type=hidden].flatpickr-input")
				.prop("disabled", false);
		}
	}
	_conditionalValueSelectorChange(event) {
		event.preventDefault();

		const mode = event.currentTarget.value;
		const container = event.currentTarget.closest(
			".advanced-filter.conditional-value-selector",
		);
		let valueSelectors = [];
		if (container.querySelector("[data-active-for]"))
			valueSelectors = container.querySelectorAll("[data-active-for]");

		for (const valueSelector of valueSelectors) {
			valueSelector.disabled = !valueSelector.dataset.activeFor?.includes(mode);
			valueSelector.classList.toggle(
				"hidden",
				!valueSelector.dataset.activeFor?.includes(mode),
			);
		}
	}
	advancedFilterChange(event) {
		event.preventDefault();
		event.stopPropagation();

		const $advancedFilter = $(event.currentTarget);

		$advancedFilter
			.removeClass((_i, classNames) =>
				classNames.split(" ").filter((c) => c.length < 2),
			)
			.addClass($advancedFilter.find(':input[name*="[m]"]').first().val());

		const type = $advancedFilter.find(':input[name*="[t]"]').first().val();

		if (type === "advanced_attributes")
			this.switchAdvancedAttributesInput(event.currentTarget);

		const params = $advancedFilter.find(":input").serializeJSON();

		this.addTagGroup(params);
	}
	addTagGroup(params) {
		DataCycle.httpRequest(this.addTagGroupPath, {
			method: "POST",
			body: params,
		})
			.then(this.renderTagGroupHtml.bind(this))
			.catch((error) => console.error(error));
	}
	renderTagGroupHtml(data) {
		const html = data?.html;
		const identifier = data?.identifier;
		const tagGroup = document.querySelector(
			`.filters .tag-group[data-id="${identifier}"]`,
		);

		if (!html && tagGroup) {
			tagGroup.remove();
		} else if (tagGroup) tagGroup.outerHTML = html;
		else if (identifier === "language")
			document
				.querySelector(".filters .languagetags")
				?.insertAdjacentHTML("beforeend", html);
		else
			document
				.querySelector(".filters .filtertags .filter-groups")
				?.insertAdjacentHTML("beforeend", html);
	}
	addAdvancedFilter(event) {
		event.preventDefault();
		event.stopPropagation();

		if (!this.$addAdvancedFilterSelect.val()) return;

		this.$addAdvancedFilterSelect.prop("disabled", true);

		DataCycle.httpRequest(this.addFilterPath, {
			method: "POST",
			body: {
				t: this.$addAdvancedFilterSelect.val(),
				n: this.$addAdvancedFilterSelect.find(":selected").data("name"),
				q: this.$addAdvancedFilterSelect.find(":selected").data("advancedtype"),
				m: this.$addAdvancedFilterSelect.data("method"),
			},
		})
			.then(this.renderAdvancedFilterHtml.bind(this))
			.catch((error) => console.error(error))
			.finally(() => {
				this.$addAdvancedFilterSelect.prop("disabled", false);
			});

		this.$addAdvancedFilterSelect.val(null).trigger("change");
	}
	renderAdvancedFilterHtml(data) {
		const addAdvancedFilterSelect = this.$addAdvancedFilterSelect[0];
		const nextElement = addAdvancedFilterSelect.closest(
			".add-advanced-filter-container",
		);

		nextElement.insertAdjacentHTML("beforebegin", data?.html);
		const insertedElement = nextElement.previousElementSibling;
		DomElementHelpers.slideDown(insertedElement).then(() => {
			insertedElement
				.querySelector('[data-initial-focus]:not([data-initial-focus="false"])')
				?.focus({ focusVisible: true });
		});

		addAdvancedFilterSelect.dataset.index += 1;
	}
	removeAdvancedFilter(event) {
		event.preventDefault();
		event.stopPropagation();

		const target = event.currentTarget.dataset.target;
		const form = this.$searchForm[0];
		form.querySelector(`.tag-group[data-id="${target}"]`)?.remove();

		const filter = form.querySelector(`[data-id="${target}"]:not(.tag-group)`);

		if (filter.classList.contains("search")) {
			const textField = filter.querySelector('input[type="text"]');
			textField.value = null;
			textField.dispatchEvent(new Event("change"));
		} else if (filter.classList.contains("advanced-filter"))
			DomElementHelpers.slideUp(filter).then(() => filter.remove());
		else filter.remove();
	}
	removeHiddenFilter(event) {
		event.preventDefault();
		event.stopPropagation();

		const target = event.currentTarget.dataset.target;
		const form = this.$searchForm[0];
		form.querySelector(`.tag-group[data-id="${target}"]`)?.remove();
		form
			.querySelector(`.hidden-filters .hidden-filter[data-id="${target}"]`)
			?.remove();
	}
	focusAdvancedFilter(event) {
		event.preventDefault();
		event.stopPropagation();

		const target = $(event.currentTarget).data("target");
		const $targetElem = $(`[data-id="${target}"]`);
		const accordion = $(event.currentTarget)
			.closest(".filters")
			.find(".advanced-filters.accordion");

		accordion.one("down.zf.accordion", (e) => {
			e.stopPropagation();

			this.highlightAdvancedFilter($targetElem);
		});

		if (accordion.length && $targetElem.closest(".accordion").length)
			accordion.foundation(
				"down",
				accordion.find("> .accordion-item > .accordion-content"),
			);
		else this.highlightAdvancedFilter($targetElem);
	}
	highlightAdvancedFilter($element) {
		$element.addClass("highlight").get(0).scrollIntoView({
			behavior: "smooth",
			block: "center",
		});

		$element
			.get(0)
			.querySelector('[data-initial-focus]:not([data-initial-focus="false"])')
			?.focus({ focusVisible: true });

		setTimeout(() => {
			$element.removeClass("highlight");
		}, 1000);
	}
	initSearchForm() {
		if (!this.$searchInput.length) return;

		this.$searchInput.on("change", this.triggerSearch.bind(this));
	}
	triggerSearch(_) {
		this.$searchForm.submit();
	}
	initClickableMenu() {
		if (!this.$clickableMenus.length) return;

		this.$primaryClickableMenu.on(
			"mouseenter",
			"li.active, li.active li",
			this.defaultFilterMouseEnter.bind(this),
		);
		this.$primaryClickableMenu.on(
			"mouseleave",
			"li.active, li.active li",
			this.defaultFilterMouseLeave.bind(this),
		);
		this.$clickableMenus.on(
			"click",
			"input",
			this.clickMainFilterInput.bind(this),
		);
		this.$clickableMenus.on("click", "> li", this.clickOnMainFilter.bind(this));
		this.$clickableMenus.on(
			"mouseleave",
			"> li.active",
			this.leaveMainFilter.bind(this),
		);
		this.$clickableMenus.on(
			"mouseleave",
			"> li.active",
			this.leaveMainFilter.bind(this),
		);
		this.$clickableMenus.on(
			"exit",
			"> li.active",
			this.leaveMainFilterInstant.bind(this),
		);
	}
	clickOnMainFilter(event) {
		if (
			$(event.currentTarget).hasClass("active") &&
			!$(event.target).parentsUntil(".clickable-menu").filter("ul").length
		) {
			$(event.currentTarget).trigger("exit");
			clearTimeout(this.leaveDebounceTimer);
		} else if (!$(event.currentTarget).hasClass("active")) {
			$(".clickable-menu .active").removeClass("active");
			$(event.currentTarget)
				.addClass("active")
				.trigger("mouseenter")
				.trigger("dc:clickableMenu:show");
			const list = $(event.currentTarget).find("> ul");
			if (!list.length) return;

			const availableHeight =
				$(window).height() +
				$(window).scrollTop() -
				$(event.currentTarget).find("> ul").offset().top;
			if (availableHeight < list.get(0).scrollHeight && availableHeight > 20)
				list.css("height", availableHeight - 20);
			else list.css("height", "");
		}
	}
	leaveMainFilter(event) {
		const currentTarget = event.currentTarget;
		this.leaveDebounceTimer = setTimeout(() => {
			if (currentTarget.querySelector("ul:hover")) return;
			currentTarget.classList.remove("active");
		}, 300);
	}
	leaveMainFilterInstant(event) {
		event.currentTarget.classList.remove("active");
	}
	clickMainFilterInput(event) {
		event.stopPropagation();
	}
	languageHandler(item, checked) {
		if ($(item).val() === "all" && checked) {
			$(item)
				.parents(".filter")
				.find(":checkbox")
				.not(item)
				.prop("checked", false);
		} else if (
			checked &&
			$(item).parents(".filter").find(":checkbox#all").is(":checked")
		) {
			$(item).parents(".filter").find(":checkbox#all").prop("checked", false);
		}
	}
}

export default DashboardFilter;
