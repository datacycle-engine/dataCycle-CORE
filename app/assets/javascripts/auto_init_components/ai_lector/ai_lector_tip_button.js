import { nanoid } from "nanoid";
import CalloutHelpers from "../../helpers/callout_helpers.js";
import QuillHelpers from "../../helpers/quill_helpers.js";
import StateMachine from "../../helpers/state_machine.js";

export default class AiLectorTipButton {
	static selector = ".ai-lector-tip-button";
	static className = "ai-lector-tip-button";
	static lazy = true;

	constructor(item) {
		this.item = item;
		this.templateName = this.item.dataset.templateName;
		this.key = this.item.dataset.key;
		this.promptType = "tip";
		this.tipKey = this.item.dataset.tipKey;
		this.locale = this.item.dataset.locale;
		this.formElement = this.item.closest(".form-element");
		this.resultContainer =
			this.item.parentElement.querySelector(".ai-lector-result");
		this.resultContent = this.resultContainer?.querySelector(
			".ai-lector-result-content",
		);
		this.resultCloseButton = this.resultContainer?.querySelector(
			".ai-lector-close-result",
		);
		this.identifier = this.item.id;
		this.streamId = null;
		this.aiLectorContainer = this.item.closest(".ai-lector-dropdown");
		this.valueField = this.formElement.querySelector(`[name="${this.key}"]`);
		this.timeout;
		this.originalContent = this.getValue();
		this.newContent = "";
		this.state = this.createStateMachine();
		this.promptContext = "";

		this.setupEventHandlers();
	}

	createStateMachine() {
		return new StateMachine({
			initialState: "idle",
			idle: {
				transitions: {
					load: "loading",
				},
				actions: {
					onEnter: () => this.reset(),
				},
			},
			loading: {
				transitions: {
					finish: "finished",
					error: "error",
					reset: "idle",
				},
				actions: {
					onEnter: () => this.loadTip(),
					onExit: () => this.contentFieldFinished(),
				},
			},
			finished: {
				transitions: {
					reset: "idle",
					load: "loading",
				},
				actions: {
					onEnter: () => this.showTipResult(),
				},
			},
			error: {
				transitions: {
					reset: "idle",
				},
				actions: {
					onEnter: (error, cssClass, key) =>
						this.renderError(error, cssClass, key),
				},
			},
		});
	}

	setupEventHandlers() {
		this.item.addEventListener("click", this.loadHandler.bind(this));
		this.item.addEventListener("data", this.dataHandler.bind(this));
		this.item.addEventListener("reset", this.resetHandler.bind(this));
		this.resultCloseButton?.addEventListener(
			"click",
			this.closeHandler.bind(this),
		);
	}

	loadHandler(event) {
		event.preventDefault();
		this.state.transition("load");
	}

	async dataHandler(event) {
		event.preventDefault();

		const data = event.detail;
		if (this.streamId !== data.stream_id) return;

		if (data?.error)
			this.state.transition("error", {
				enter: [data.error],
			});
		else if (data?.warning)
			this.state.transition("error", {
				enter: [data.warning, "info", "warnings"],
			});
		else if (data?.data) this.appendData(data.data);

		if (data?.finished) this.state.transition("finish");
	}

	resetHandler(event) {
		event.preventDefault();
		this.state.transition("reset");
	}

	closeHandler(event) {
		event.preventDefault();
		this.state.transition("reset");
	}

	getValue() {
		if (this.valueField.type === "hidden")
			QuillHelpers.updateEditors(this.formElement);
		return this.valueField.value;
	}

	setValue(value) {
		this.valueField.value = value;

		if (this.valueField.type === "hidden") {
			const editor = this.formElement.querySelector(".quill-editor");

			$(editor).trigger("dc:import:data", {
				force: true,
				value: value,
			});
		}
	}

	contentFieldLoading() {
		this.clearNeighboringResults();
		DataCycle.disableElement(this.item);

		return I18n.translate("feature.ai_lector.diff.thinking").then((text) => {
			this.resultContent.textContent = text;
			this.resultContent.classList.add("ellipsis-loading");
			this.resultContainer.classList.add("visible");
		});
	}

	clearNeighboringResults() {
		const neighboring = this.aiLectorContainer.querySelectorAll(
			":scope > ul > li > button",
		);
		for (const result of neighboring) {
			if (result.id !== this.identifier) {
				result.dispatchEvent(new Event("reset"));
			}
		}
	}

	contentFieldFinished() {
		if (this.state.value === "idle") return;

		this.streamId = null;
		this.newContent = "";
		if (this.timeout) clearTimeout(this.timeout);
		this.resultContent?.classList.remove("ellipsis-loading");
		DataCycle.enableElement(this.item);
	}

	reset() {
		this.contentFieldFinished();
		this.originalContent = this.getValue();
		this.promptContext = "";

		if (this.resultContent) {
			this.resultContent.textContent = "";
			this.resultContent.classList.remove("ellipsis-loading");
			this.resultContainer.classList.remove("visible");
		}
	}

	async renderError(error, cssClass = "alert", key = "errors") {
		let message = error;
		if (!message) {
			message = await I18n.translate(`feature.ai_lector.${key}.generic`);
		}
		CalloutHelpers.show(message, cssClass);
		this.state.transition("reset");
	}

	showTipResult() {
		if (!this.newContent.trim()) return;

		this.resultContent.textContent = this.newContent;
		this.resultContainer.classList.add("visible");
	}

	appendData(data) {
		if (this.timeout) clearTimeout(this.timeout);
		this.timeout = setTimeout(this.contentFieldFinished.bind(this), 30000);
		this.newContent += data;
		this.resultContent.textContent = this.newContent;
	}

	requestBody() {
		return {
			prompt_type: this.promptType,
			text: this.originalContent,
			locale: this.locale,
			template_name: this.templateName,
			key: this.key,
			tip_key: this.tipKey,
			identifier: this.identifier,
			stream_id: this.streamId,
		};
	}

	sendQuery(context = {}) {
		try {
			this.streamId = nanoid();
			const requestData = this.requestBody();
			if (context) Object.assign(requestData, context);

			DataCycle.globals.aiLector.send(requestData);
		} catch (_error) {
			I18n.t("feature.ai_lector.warnings.no_connection").then((text) => {
				this.state.transition("error", { enter: [text, "info"] });
			});
		}
	}

	async loadTip() {
		await this.contentFieldLoading();

		this.sendQuery();
	}
}
