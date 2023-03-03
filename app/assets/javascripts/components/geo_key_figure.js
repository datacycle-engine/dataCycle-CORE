class GeoKeyFigure {
	constructor(element) {
		element.classList.add("dcjs-geo-key-figure");
		this.$element = $(element);
		this.url = this.$element.prop("href");
		this.$formElement = this.$element.closest(".form-element");
		this.$triggerAllButton = this.$element
			.closest(".content-object-item, .attribute-group.editor.has-title")
			.find(".geo-key-figure-button-all");
		this.key = this.$element.data("key");
		this.fullKey = this.$element.data("fullKey");
		this.local = this.$element.data("local");
		this.configuration = this.$element.data("configuration");
		this.partIdPath = this.configuration.part_id_path;
		this.attributeKeyMapping = this.configuration.attribute_key_mapping;
		this.attributeKeyMappingSource =
			this.configuration.attribute_key_mapping_source;
		this.label = this.$formElement.data("label");
		this.locale =
			this.$formElement.closest("form").find(':hidden[name="locale"]').val() ||
			"";

		this.setup();
	}
	setup() {
		if (!(this.partIdPath && this.key)) {
			console.warn("GeoKeyFigure: missing parameter");
			return;
		}

		this.$element.on("click", this._computeKeyFigure.bind(this));
		this.$triggerAllButton.on("click", this._computeKeyFigure.bind(this));

		if (!this.local) {
			this.setButtonStatus(false, { ids: this.getValues() });
			$(this.partSelectorString()).on(
				"dc:objectBrowser:change",
				this.setButtonStatus.bind(this),
			);
		} else {
			$(this.partSelectorString())
				.find(DataCycle.config.EditorSelectors.join(", "))
				.on(
					"dc:map:elevationProfileInitialized",
					this.enableButtons.bind(this),
				);
		}
	}
	partSelectorString(keyPath = this.partIdPath) {
		return `.form-element${keyPath
			.map((v) => `[data-key*="[${v}]"]`)
			.join("")}`;
	}
	getValues() {
		return $(this.partSelectorString())
			.find(":input")
			.serializeArray()
			.map((v) => v?.value)
			.filter(Boolean);
	}
	_computeKeyFigure(event) {
		event.preventDefault();
		event.stopPropagation();

		if (this.$element.hasClass("disabled")) return;

		DataCycle.disableElement(this.$element);

		if (this.local) {
			this._computeByLocal();
		} else {
			this.sendRequest();
		}
	}
	_getKeyBySourceMapping() {
		let attributeKey = this.key;
		let attributeKeyIndex = -1;
		const $sourceEditor = $(
			this.partSelectorString([this.attributeKeyMappingSource]),
		).find(DataCycle.config.EditorSelectors.join(", "));

		if (!$sourceEditor.is("select")) return attributeKey;

		const selectedPath = $sourceEditor
			.find("option:selected")
			.map((_i, e) => e.dataset.fullPath)
			.get();

		for (const path of selectedPath) {
			const parts = path.split(" > ");
			parts.shift();

			for (const [index, cl] of parts.entries()) {
				for (const [key, value] of Object.entries(this.attributeKeyMapping)) {
					let matchingIndex = -1;

					if (cl.trim().toLowerCase() === key.trim().toLowerCase())
						matchingIndex = index * 2;
					else if (cl.trim().toLowerCase().includes(key.trim().toLowerCase()))
						matchingIndex = index;

					if (attributeKeyIndex < matchingIndex) {
						attributeKey = value;
						attributeKeyIndex = index;
					}
				}
			}
		}

		return attributeKey;
	}
	_attributeNameFromKey() {
		let attributeKey;

		if (
			this.attributeKeyMapping &&
			typeof this.attributeKeyMapping === "string"
		)
			attributeKey = this.attributeKeyMapping;
		else if (this.attributeKeyMapping && this.attributeKeyMappingSource)
			attributeKey = this._getKeyBySourceMapping();
		else attributeKey = this.key;

		return attributeKey;
	}
	async _computeByLocal() {
		await $(this.partSelectorString())
			.find(DataCycle.config.EditorSelectors.join(", "))
			.triggerHandler("dc:geoKeyFigure:compute", {
				attributeKey: this._attributeNameFromKey(),
				callback: this.setNewValue.bind(this),
			});

		DataCycle.enableElement(this.$element);
	}
	sendRequest() {
		const value = this.getValues();

		if (!value?.length) return DataCycle.enableElement(this.$element);

		DataCycle.httpRequest(this.url, {
			method: "POST",
			body: {
				key: this._attributeNameFromKey(),
				part_ids: value,
			},
		})
			.then((data) => {
				if (data) {
					if (data.newValue) this.setNewValue(data.newValue);
					if (data.error) this.showErrorMessage(data.error);
				}
			})
			.catch(async () => {
				this.showErrorMessage(
					await I18n.translate("frontend.validate.errors.endpoint_error"),
				);
			})
			.finally(() => {
				DataCycle.enableElement(this.$element);
			});
	}
	async setNewValue(value) {
		if (typeof value !== "number") {
			this.showErrorMessage(
				await I18n.translate("frontend.validate.errors.key_figure_not_found"),
			);

			return;
		}

		this.$formElement
			.find(DataCycle.config.EditorSelectors.join(", "))
			.trigger("dc:import:data", {
				value: value,
				locale: this.locale,
			});
	}
	showErrorMessage(message) {
		$("body").trigger("dc:flash:renderMessage", {
			type: "alert",
			text: message,
		});
	}
	setButtonStatus(event, data) {
		if (event) {
			event.preventDefault();
			event.stopPropagation();
		}

		if (data.ids.length > 0) {
			this.enableButtons();
		} else {
			this.disableButtons();
		}
	}
	enableButtons() {
		DataCycle.enableElement(this.$element);
		DataCycle.enableElement(this.$triggerAllButton);
	}
	disableButtons() {
		DataCycle.disableElement(this.$element, this.$element.html());
		DataCycle.disableElement(
			this.$triggerAllButton,
			this.$triggerAllButton.html(),
		);
	}
}

export default GeoKeyFigure;
