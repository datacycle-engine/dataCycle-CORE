import DomElementHelpers from "../helpers/dom_element_helpers";

class AttributeLocaleSwitcher {
	constructor(localeSwitch) {
		localeSwitch.classList.add("dcjs-attribute-locale-switcher");
		this.$localeSwitch = $(localeSwitch);
		this.$container = this.$localeSwitch
			.closest(".reveal, #edit-form, .inner-container, .split-content")
			.first();
		this.$form = this.$container.find("form.validation-form").first();
		this.$localeFormField = this.$form.find(':input[name="locale"]');
		this.locale = this.$localeFormField.val() || "de";
		this.localeUrlParameter =
			this.$localeSwitch.data("locale-url-parameter") || "locale";

		this.init();
	}
	init() {
		this.$localeSwitch.on(
			"click",
			".available-attribute-locale",
			this.changeTranslation.bind(this),
		);
		this.$localeFormField.on("change", this.updateLocale.bind(this));
		this.$form.on(
			"dc:form:validationError",
			this.updateLocaleWithError.bind(this),
		);
		this.$form.on(
			"dc:form:removeValidationError",
			this.removeLocaleError.bind(this),
		);
		$(window).on("popstate", this.reloadState.bind(this));
	}
	reloadState(_event) {
		if (history.state?.locale)
			this.$localeSwitch
				.find(
					`.available-attribute-locale[data-locale="${history.state.locale}"]`,
				)
				.trigger("click", { preventHistory: true });
	}
	updateLocaleWithError(event, data) {
		event.preventDefault();

		if (!data.locale) return;

		this.$localeSwitch
			.find(`.available-attribute-locale[data-locale="${data.locale}"]`)
			.addClass(`validation-${data.type}`);
	}
	removeLocaleError(event, data) {
		event.preventDefault();

		if (data.locale)
			this.$localeSwitch
				.find(
					`.available-attribute-locale.validation-${data.type}[data-locale="${data.locale}"]`,
				)
				.removeClass(`validation-${data.type}`);
		else
			this.$localeSwitch
				.find(`.available-attribute-locale.validation-${data.type}`)
				.removeClass(`validation-${data.type}`);
	}
	pushStateToHistory() {
		const url = new URL(window.location);
		url.searchParams.set(this.localeUrlParameter, this.locale);
		history.pushState({ locale: this.locale }, "", url);
	}
	changeTranslation(event, data = null) {
		event.preventDefault();
		event.stopPropagation();

		const $target = $(event.currentTarget);

		this.locale = $target.data("locale");
		$target
			.closest(".attribute-locale-switcher")
			.find(".active")
			.removeClass("active");
		$target.parent("li").addClass("active");

		if (this.$container.find(".split-content").length)
			this.changeTranslationRecursive(
				this.$container.find(".split-content.edit-content"),
			);
		else this.changeTranslationRecursive(this.$container);

		this.updateLocaleRecursive(
			this.$form.length ? this.$form : this.$container,
		);

		if (!data?.preventHistory) this.pushStateToHistory();
	}
	changeTranslationRecursive($container) {
		$container.find(".template-locale").text(`(${this.locale})`);

		$container
			.find(
				`.translatable-attribute.${this.locale}, .translatable-field.${this.locale}`,
			)
			.each((_index, item) => {
				if ($(item).siblings(".active").length) {
					$(item).siblings(".active").removeClass("active");
					$(item).addClass("active").trigger("dc:remote:render");
					if ($(item).find(".is-embedded-title").length)
						$(item)
							.find(".is-embedded-title")
							.trigger("dc:embedded:changeTitle");
				}
			});

		$container
			.find(
				".edit-content-link, a.show-link, a.edit-link, a.load-more-linked-contents, a.load-as-split-source-link",
			)
			.each((_index, item) => {
				if (item.nodeName === "BUTTON") {
					const $inputField = $(item).siblings('[name="locale"]');

					if ($inputField.length) $inputField.val(this.locale);
					else
						$(item).after(
							`<input type="hidden" name="locale" value="${this.locale}">`,
						);
				} else {
					const url = new URL(item.href);
					url.searchParams.set("locale", this.locale);
					item.href = url;
				}
			});

		$container.find("[data-open], [data-toggle]").each((_index, item) => {
			this.changeTranslationRecursive(
				$(`#${$(item).data("open") || $(item).data("toggle")}`),
			);
		});
	}
	updateLocale(event) {
		this.$localeSwitch
			.find(
				`.available-attribute-locale[data-locale="${$(event.target).val()}"]`,
			)
			.trigger("click", { preventHistory: true });
	}
	updateLocaleRecursive(container) {
		let element = container;
		if (element instanceof $) element = element.get(0);

		const objectBrowserSelector = ".object-browser";
		if (element.querySelector(objectBrowserSelector))
			for (const elem of element.querySelectorAll(objectBrowserSelector)) {
				if (elem.dataset.locale !== this.locale) {
					elem.dataset.locale = this.locale;
					$(elem).trigger("dc:locale:changed");
				}
			}

		const remoteRenderSelector =
			".remote-render:not(.translatable-attribute):not(.translatable-field)";
		if (element.querySelector(remoteRenderSelector))
			for (const elem of element.querySelectorAll(remoteRenderSelector)) {
				const remoteOptions = DomElementHelpers.parseDataAttribute(
					elem.dataset.remoteOptions,
				);

				if (
					remoteOptions?.locale !== undefined &&
					remoteOptions?.locale !== this.locale
				) {
					remoteOptions.locale = this.locale;
					elem.dataset.remoteOptions = JSON.stringify(remoteOptions);
				}
			}

		const inputSelector = 'input[name="locale"], select[name="locale"]';
		if (element.querySelector(inputSelector))
			for (const elem of element.querySelectorAll(inputSelector)) {
				if (elem.value !== this.locale) elem.value = this.locale;
			}

		const multiStepFormSelector = "form.multi-step";
		if (element.querySelector(multiStepFormSelector))
			for (const elem of element.querySelectorAll(multiStepFormSelector)) {
				if (elem.dataset.locale !== this.locale)
					elem.dataset.locale = this.locale;
			}

		const dataOpenSelector = "[data-open], [data-toggle]";
		if (element.querySelector(dataOpenSelector))
			for (const elem of element.querySelectorAll(dataOpenSelector)) {
				this.updateLocaleRecursive(
					document.getElementById(elem.dataset.open || elem.dataset.toggle),
				);
			}

		const embeddedSelector = ".form-element > .embedded-object";
		if (element.querySelector(embeddedSelector))
			for (const elem of element.querySelectorAll(embeddedSelector)) {
				if (elem.dataset.locale !== this.locale)
					elem.dataset.locale = this.locale;
			}
	}
}

export default AttributeLocaleSwitcher;
