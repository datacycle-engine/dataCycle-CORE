import BasicSelect2 from "./basic_select2";

class SimpleSelect2 extends BasicSelect2 {
	constructor(element) {
		super(element);

		this.eventHandlers.createOption = this.createOption.bind(this);
		this.eventHandlers.reloadData = this.reloadData.bind(this);
	}
	options() {
		return Object.assign({}, this.defaultOptions, {
			width: "100%",
			matcher: this.matcher.bind(this),
			language: this.languageOptions(),
		});
	}
	initSpecificEventHandlers() {
		this.$element.on("dc:create:option", this.eventHandlers.createOption);
		this.$element
			.closest(".form-element")
			.on("dc:upload:filesChanged", this.eventHandlers.reloadData);
	}
	destroy(event) {
		super.destroy(event);

		this.$element.off("dc:create:option", this.eventHandlers.createOption);
		this.$element
			.closest(".form-element")
			.off("dc:upload:filesChanged", this.eventHandlers.reloadData);
	}
	async loadNewOptions(value, newOptions) {
		await this.$element.val(value.concat(newOptions)).trigger("change");
	}
	createOption(_event, data) {
		const newOption = new Option(data.text, data.id, false, false);
		this.$element.append(newOption).trigger("change");
	}
	languageOptions() {
		return {
			searching: this.languageSearching.bind(this),
		};
	}
	languageSearching(params) {
		this.query = params;

		return "";
	}
	matcher(params, data) {
		if (params.term === undefined || !params.term.trim().length) {
			return data;
		}

		if (typeof data.text === "undefined") {
			return null;
		}

		if (
			data.element.tagName === "OPTGROUP" &&
			typeof data.children === "undefined"
		) {
			return null;
		}

		const filteredChildren = [];
		$.each(data.children, (_idx, child) => {
			if (this.optionMatches(child, params)) {
				filteredChildren.push(child);
			}
		});

		if (filteredChildren.length) {
			const modifiedData = $.extend({}, data, true);
			modifiedData.children = filteredChildren;

			return modifiedData;
		}

		if (this.optionMatches(data, params)) {
			return data;
		}

		return null;
	}
	optionMatches(data, params) {
		const title = data.element?.dataset.fullPath
			? data.element.dataset.fullPath
			: data.text;

		return title.toLowerCase().indexOf(params.term.toLowerCase()) > -1;
	}
	reloadData(event) {
		event.preventDefault();

		const reloadPath = this.config.reloadPath;
		const type = this.config.type;

		if (!(reloadPath?.length && type && type.length)) return Promise.reject();

		const promise = DataCycle.httpRequest(reloadPath, { body: { type: type } });

		promise.then((data) => {
			if (!data?.length) return;

			for (const d of data) {
				if (!this.$element.find(`option[value='${d[1]}']`).length)
					this.$element
						.append(new Option(d[0], d[1], false, false))
						.trigger("change");
			}
		});

		return promise;
	}
}

export default SimpleSelect2;
