import CalloutHelpers from "../helpers/callout_helpers";

const QuillCustomHandlers = {
	quillInlineTranslator: null,
	icons: {
		insertNbsp: `<span data-dc-tooltip><svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px" fill="#000000"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M18 9v4H6V9H4v6h16V9z"/></svg></span>`,
		replaceAllNbsp: `<span data-dc-tooltip><svg class="spacebar-icon" xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px" fill="#000000"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M18 9v4H6V9H4v6h16V9z"/></svg><svg class="times-icon" xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px" fill="#000000"><path d="M0 0h24v24H0z" fill="none"/><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg></span>`,
		inlineTranslator: `<span data-dc-tooltip><i class="fa fa-language" aria-hidden="true"></i></span>`,
	},
	insertNbsp(_value) {
		if (this.quill.options.readOnly) return;

		const selection = this.quill.getSelection(true);
		this.quill.insertText(selection, "\u00a0");
	},
	async loadIconsWithTooltips(icons, toolbarConfig) {
		for (const key of toolbarConfig) {
			if (typeof key === "string" && Object.hasOwn(this.icons, key))
				await this.loadIconTranslation(icons, key);
		}
	},
	async replaceAllNbsp(_value) {
		if (this.quill.options.readOnly) return;

		this.quill.disable();

		this.quill.clipboard.dangerouslyPasteHTML(
			this.quill.root.innerHTML.replaceAll("&nbsp;", " "),
		);

		const warningContainer = document.createElement("span");
		warningContainer.className = "quill-notice";
		warningContainer.textContent = await I18n.translate(
			"frontend.text_editor.replaced_all_nbsp",
		);

		this.quill.theme.modules.toolbar.container
			.querySelector(".ql-replaceAllNbsp")
			.after(warningContainer);

		this.quill.enable();

		setTimeout(() => {
			$(warningContainer).fadeOut("fast", () => {
				warningContainer.remove();
			});
		}, 1000);
	},
	async inlineTranslator(_value) {
		if (this.quill.options.readOnly) return;

		this.quill.disable();

		const button = this.quill.root
			.closest(".editor-block")
			.querySelector(".ql-inlineTranslator");
		const value = this.quill.root.innerHTML;

		DataCycle.disableElement(
			button,
			'<i class="fa fa-spinner fa-spin fa-fw"></i>',
		);

		DataCycle.httpRequest("/things/translate_text", {
			method: "POST",
			body: {
				text: typeof value === "string" ? value.trim() : value,
				target_locale: this.quill.root.parentElement.dataset.locale,
			},
		})
			.then(
				async ({ text, detected_source_language: detectedSourceLocale }) => {
					this.quill.clipboard.dangerouslyPasteHTML(text);

					CalloutHelpers.show(
						await I18n.translate("feature.translate.inline_success", {
							source_locale:
								detectedSourceLocale &&
								(await I18n.translate(
									`locales.${detectedSourceLocale.toLowerCase()}`,
									{},
									detectedSourceLocale.toLowerCase(),
								)),
							target_locale: await I18n.translate(
								`locales.${this.quill.root.parentElement.dataset.locale}`,
								{},
								this.quill.root.parentElement.dataset.locale,
							),
						}),
						"success",
					);
				},
			)
			.catch(async (error) => {
				let errorMessage = await I18n.translate(
					"frontend.split_view.translate_error",
					{
						label: this.quill.root.closest(".form-element").dataset.label,
					},
				);
				if (error?.responseJSON?.error)
					errorMessage += `<br><i>${error.responseJSON.error}</i>`;
				CalloutHelpers.show(errorMessage, "alert");
			})
			.finally(() => {
				DataCycle.enableElement(button);
				this.quill.enable();
			});
	},
	async loadIconTranslation(icons, key) {
		const text = await I18n.translate(`frontend.text_editor.${key}`);

		icons[key] = this.icons[key].replace(
			"data-dc-tooltip",
			`data-dc-tooltip="${text}"`,
		);
	},
};

Object.freeze(QuillCustomHandlers);

export default QuillCustomHandlers;
