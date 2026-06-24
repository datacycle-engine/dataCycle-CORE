import htmldiff from "../../components/htmldiff.js";
import StateMachine from "../../helpers/state_machine.js";
import AiLectorTipButton from "./ai_lector_tip_button.js";

export default class AiLectorImprovementButton extends AiLectorTipButton {
	static selector = ".ai-lector-improvement-button";
	static className = "ai-lector-improvement-button";
	static lazy = true;

	constructor(item) {
		super(item);

		this.contentId = this.item.dataset.contentId;
		this.promptType = this.item.dataset.promptType;
		this.label = this.formElement.dataset.label;
		this.tooltip = null;
		this.selectedProperties = [];
		this.contextOverlayId = `${this.identifier}-context-overlay`;
		this.contextModal = document.getElementById(this.contextOverlayId);
		this.diffOverlayId = `${this.identifier}-diff-overlay`;
		this.diffModal = document.getElementById(this.diffOverlayId);
		this.finetuneOverlayId = `${this.identifier}-finetune-overlay`;
		this.finetuneModal = document.getElementById(this.finetuneOverlayId);

		this.setupOverlays();
	}

	createStateMachine() {
		return new StateMachine({
			initialState: "idle",
			idle: {
				transitions: {
					load: {
						target: "loadingContext",
						action: () => this.submitContext(),
					},
					showContext: "context",
				},
				actions: {
					onEnter: () => this.reset(),
				},
			},
			context: {
				transitions: {
					load: {
						target: "loadingContext",
						action: () => this.submitContext(),
					},
					reset: "idle",
				},
				actions: {
					onEnter: () => this.showModal(this.contextModal),
					onExit: () => this.hideModal(this.contextModal),
				},
			},
			loadingContext: {
				transitions: {
					finish: "showDiff",
					error: {
						target: "error",
						action: () => this.hideModal(this.diffModal),
					},
					reset: {
						target: "idle",
						action: () => this.hideModal(this.diffModal),
					},
				},
				actions: {
					onEnter: () => this.showDiffLoadingOverlay(),
				},
			},
			showDiff: {
				transitions: {
					finetune: "finetuning",
					accept: {
						target: "idle",
						action: () => {
							this.setValue(this.newContent);
							this.hideModal(this.diffModal);
						},
					},
					error: "error",
					reset: {
						target: "idle",
						action: () => this.hideModal(this.diffModal),
					},
				},
				actions: {
					onEnter: () => this.showDiffOverlay(),
				},
			},
			finetuning: {
				transitions: {
					load: {
						target: "loadingContext",
						action: () => this.submitContext(),
					},
					reset: "showDiff",
				},
				actions: {
					onEnter: () => this.showModal(this.finetuneModal),
					onExit: () => this.hideModal(this.finetuneModal),
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

	loadHandler(event) {
		event.preventDefault();

		if (this.contextModal) this.state.transition("showContext");
		else this.state.transition("load");
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

		if (data?.finished) {
			this.newContent = data.data || "";
			this.state.transition("finish");
		}
	}

	async showDiffOverlay() {
		this.streamId = null;
		DataCycle.enableElement(this.diffForm);
		this.diffContainer.classList.remove("ellipsis-loading");

		if (!this.newContent.trim()) return;

		this.diffContainer.innerHTML = htmldiff(
			this.originalContent,
			this.newContent,
		);
	}

	acceptHandler(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.state.transition("accept");
	}

	async submitFeedbackHandler(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const textarea = this.finetuneModal.querySelector(
			".ai-lector-feedback-textarea",
		);

		this.promptContext = textarea.value.trim();
		this.state.transition("load");
	}

	setupOverlays() {
		this.setupModal(this.contextModal, this.initContextModal.bind(this));
		this.setupModal(this.diffModal, this.initDiffModal.bind(this));
		this.setupModal(this.finetuneModal, this.initFinetuneModal.bind(this));
	}

	setupModal(modal, initFunction) {
		if (!modal) return;

		modal.addEventListener("turbo:frame-load", initFunction);

		$(modal).on("closed.zf.reveal", this.closeModalHandler.bind(this));
	}

	initDiffModal() {
		this.diffForm = this.diffModal.querySelector(".ai-lector-diff-form");
		this.diffContainer = this.diffModal.querySelector(
			".ai-lector-diff-content",
		);

		this.diffForm.addEventListener("submit", this.acceptHandler.bind(this));
		this.diffModal
			.querySelector(".ai-lector-finetune-button")
			?.addEventListener("click", this.finetuneHandler.bind(this));
	}

	resetDiffModal() {
		this.diffContainer.classList.add("ellipsis-loading");
		DataCycle.disableElement(this.diffForm);

		I18n.t("feature.ai_lector.diff.thinking").then((text) => {
			this.diffContainer.textContent = text;
		});
	}

	initFinetuneModal() {
		this.finetuneForm = this.finetuneModal.querySelector(
			".ai-lector-finetune-form",
		);

		this.finetuneForm.addEventListener(
			"submit",
			this.submitFeedbackHandler.bind(this),
		);
	}

	initContextModal() {
		this.contextForm = this.contextModal.querySelector(
			".ai-lector-context-form",
		);

		this.contextForm.addEventListener(
			"submit",
			this.submitContextHandler.bind(this),
		);
	}

	finetuneHandler(event) {
		event.preventDefault();
		event.stopImmediatePropagation();
		this.state.transition("finetune");
	}

	closeModalHandler(_event) {
		if (!this.state.inTransition) this.state.transition("reset");
	}

	resetModal(modal) {
		this.streamId = null;

		if (modal.querySelector("form")) {
			for (const form of modal.querySelectorAll("form")) {
				form.reset();
				DataCycle.enableElement(form);
			}
		}
	}

	waitForModal(modal) {
		return new Promise((resolve) => {
			if (modal.hasAttribute("complete")) {
				resolve();
			} else {
				modal.addEventListener(
					"turbo:frame-load",
					() => {
						resolve();
					},
					{ once: true },
				);
			}
		});
	}

	showModal(modal) {
		const $modal = $(modal);
		if (typeof $modal.foundation === "function") $modal.foundation("open");

		return this.waitForModal(modal);
	}

	hideModal(modal) {
		this.resetModal(modal);
		const $modal = $(modal);
		if (typeof $modal.foundation === "function") $modal.foundation("close");
	}

	requestBody() {
		return Object.assign({}, super.requestBody(), {
			content_id: this.contentId,
			selected_content_ids: this.selectedContentIds || [],
			selected_property_data: this.selectedPropertyData || [],
		});
	}

	submitContextHandler(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const textarea = this.contextModal.querySelector(
			".ai-lector-context-textarea",
		);
		this.promptContext = textarea.value.trim();
		this.state.transition("load");
	}

	contextOptions() {
		switch (this.state.value) {
			case "idle":
				return {};
			case "context": {
				return {
					user_context: this.promptContext,
				};
			}
			case "finetuning": {
				return {
					feedback: this.promptContext,
					previous_response: this.newContent,
				};
			}
		}
	}

	async submitContext() {
		this.originalContent = this.getValue();
		const contextOptions = this.contextOptions();
		this.newContent = "";

		return this.sendQuery(contextOptions);
	}

	async showDiffLoadingOverlay() {
		await this.showModal(this.diffModal);
		this.resetDiffModal();
	}
}
