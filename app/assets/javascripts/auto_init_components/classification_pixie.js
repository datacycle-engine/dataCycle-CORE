import escapeHtml from "lodash/escape";
import PixieHelpers from "../helpers/pixie_helpers";

class ClassificationPixie {
	static selector = ".classification-pixie-form";
	static className = "dcjs-classification-pixie";
	constructor(content) {
		this.reveal = content.closest(".reveal");
		this.form = content;
		this.resultsContainer = this.form?.querySelector(".classification-results");
		this.applyButton = this.form?.querySelector(
			".apply-classifications-button",
		);
		this.clearSelectionButton = this.form?.querySelector(".clear-button");
		this.searchInput = this.form?.querySelector(
			".classification-pixie-tree-search",
		);
		this.treeItems = Array.from(
			this.form?.querySelectorAll(".classification-pixie-tree-item") || [],
		);
		this.selectedTreeId = "";
		this.selectedPropertyKey = "";
		this.resultsCache = new Map();

		this.setup();
	}

	setup() {
		if (!this.form || !this.resultsContainer) return;
		this.resultsContainer.addEventListener("change", (event) => {
			this.handleCheckboxChange(event);
		});
		this.treeItems.forEach((item) => {
			item.addEventListener("click", (event) => {
				event.preventDefault();
				event.stopPropagation();
				this.handleTreeSelect(item);
			});
		});
		if (this.searchInput) {
			this.searchInput.addEventListener("input", (event) => {
				this.handleTreeSearch(event.target.value);
			});
		}

		this.setActionButtonsEnabled(false);
		this.updateButtonsState();

		this.bindClick(this.applyButton, () => this.handleApplyClassifications());
		this.bindClick(this.clearSelectionButton, () => this.handleClear());
	}

	bindClick(element, handler) {
		if (!element) return;
		element.addEventListener("click", (event) => {
			event.preventDefault();
			event.stopPropagation();
			handler(event);
		});
	}

	async t(key, defaultText, substitutions = {}) {
		return I18n.translate(key, { default: defaultText, ...substitutions });
	}

	/**
	 * The message is escaped for the same reason `id`, `label` and `reasoning` are below: its first
	 * source is `error.responseBody.error`, which carries the classification service's own wording
	 * through LocalizationService -- so it is service-controlled text going into innerHTML.
	 * PixieHelpers.renderMessage answers the same question with textContent.
	 */
	async renderClassifierError(message) {
		const title = await this.t(
			"frontend.classification_pixie.classification_error_title",
			"Classification Error",
		);
		this.resultsContainer.innerHTML = `
			<div class="callout alert">
				<h4>${title}</h4>
				<p style="margin: 0.5rem 0;">${escapeHtml(message ?? "")}</p>
			</div>
		`;
	}

	async renderApplyMessage(message, isError) {
		const typeClass = isError ? "alert" : "success";
		const title = isError
			? await this.t(
					"frontend.classification_pixie.apply_error_title",
					"Apply Error",
				)
			: await this.t(
					"frontend.classification_pixie.applied_title",
					"Classifications Applied",
				);

		this.resultsContainer.innerHTML = `
			<div class="callout ${typeClass}">
				<h4>${title}</h4>
				<p style="margin: 0.5rem 0;">${escapeHtml(message ?? "")}</p>
			</div>
		`;
	}

	/**
	 * Renders the classifier's answer into `resultsContainer.innerHTML`. `id`, `label` and
	 * `reasoning` are free-form strings of the workflow's response contract, and each is
	 * interpolated both into element content and into a `data-` attribute the apply step reads
	 * back, so all three are escaped. `confidence` needs none: `Number.parseFloat` and the clamp
	 * below leave only a number or the "not available" label.
	 */
	async renderClassifierResults(suggestions, details, options = {}) {
		const resultsTitle = await this.t(
			"frontend.classification_pixie.results_title",
			"Classification Results",
		);
		const unknownLabel = await this.t(
			"frontend.classification_pixie.unknown_label",
			"Unknown",
		);
		const notAvailable = await this.t(
			"frontend.classification_pixie.not_available",
			"n/a",
		);
		const noClassifications = await this.t(
			"frontend.classification_pixie.no_classifications",
			"No classifications returned.",
		);
		const summaryText = suggestions.length
			? await this.t(
					"frontend.classification_pixie.classifications_suggested",
					"%{count} classifications suggested.",
					{ count: suggestions.length },
				)
			: "";

		const listItems = suggestions
			.map((item, index) => {
				const idValue = escapeHtml(item.id || "");
				const label = escapeHtml(item.label || item.id || unknownLabel);
				const reasoningText = escapeHtml(item.reasoning || "");
				const confidenceValue =
					item.confidence !== undefined && item.confidence !== null
						? item.confidence
						: "";
				const confidenceNumber = Number.isFinite(confidenceValue)
					? confidenceValue
					: Number.parseFloat(confidenceValue);
				const hasConfidence = Number.isFinite(confidenceNumber);
				const safeConfidence = hasConfidence
					? Math.max(0, Math.min(100, confidenceNumber))
					: null;
				const confidenceText = hasConfidence
					? `${safeConfidence}%`
					: notAvailable;
				const confidenceLevelClass = hasConfidence
					? safeConfidence >= 90
						? " is-max"
						: safeConfidence >= 70
							? " is-high"
							: " is-low"
					: "";
				const confidenceClass = hasConfidence
					? confidenceLevelClass
					: " is-unknown";
				const confidenceBarStyle = hasConfidence
					? `style="width: ${safeConfidence}%;"`
					: "";
				const reasoning = reasoningText
					? `<p class="classification-pixie-suggestion-reasoning">${reasoningText}</p>`
					: "";
				const inputId = `classification_${details.contentId}_${index}`;
				return `
					<li class="classification-pixie-suggestion">
						<label class="classification-pixie-suggestion-label" for="${inputId}">
							<input
								type="checkbox"
								id="${inputId}"
								class="classification-checkbox"
								data-id="${idValue}"
								data-label="${label}"
								data-confidence="${confidenceValue}"
								data-reasoning="${reasoningText}"
								checked
							/>
							<span class="classification-pixie-suggestion-text">
								<span class="classification-pixie-suggestion-title">${label}</span>
								<span class="classification-pixie-suggestion-confidence${confidenceClass}">${confidenceText}</span>
							</span>
						</label>
						<div class="classification-pixie-suggestion-bar" aria-hidden="true">
							<span class="classification-pixie-suggestion-bar-fill${confidenceLevelClass}" ${confidenceBarStyle}></span>
						</div>
						${reasoning}
					</li>
				`;
			})
			.join("");

		const summaryMarkup = summaryText ? `<p>${summaryText}</p>` : "";
		const emptyMessage = options.emptyMessage || noClassifications;
		const suggestionsMarkup = listItems
			? listItems
			: `<li class="classification-pixie-suggestion empty">${emptyMessage}</li>`;
		this.resultsContainer.innerHTML = `
			<div class="classification-pixie-results">
				<div class="classification-pixie-results-header">
					<h4>${resultsTitle}</h4>
					${summaryMarkup}
				</div>
				<ul class="classification-pixie-suggestions">
					${suggestionsMarkup}
				</ul>
			</div>
		`;

		if (this.applyButton) {
			this.applyButton.dataset.contentId = details.contentId;
			this.applyButton.dataset.classificationTreeId =
				details.classificationTreeId;
			this.applyButton.dataset.propertyKey = details.propertyKey || "";
		}

		this.revealActionButtons();
	}

	async renderLoadingMessage() {
		const loadingText = await this.t("common.loading", "Loading...");
		this.resultsContainer.innerHTML = `
			<div class="classification-pixie-results classification-pixie-loading">
				<i class="fa fa-spinner fa-spin" aria-hidden="true"></i>
				<span>${loadingText}</span>
			</div>
		`;
	}

	setSelectedTree(treeId, propertyKey = "", { clearResults = true } = {}) {
		this.selectedTreeId = treeId;
		this.selectedPropertyKey = propertyKey;
		this.treeItems.forEach((item) => {
			const isActive = item.dataset.treeId === treeId;
			item.classList.toggle("is-active", isActive);
			item.setAttribute("aria-pressed", isActive ? "true" : "false");
		});
		if (clearResults) {
			this.handleClear();
		}
	}

	handleTreeSelect(item) {
		const treeId = item?.dataset.treeId || "";
		const propertyKey = item?.dataset.propertyKey || "";
		if (!treeId) return;
		if (treeId === this.selectedTreeId) {
			if (!this.resultsCache.has(treeId)) {
				this.handleClassifyClick();
			}
			return;
		}
		this.setSelectedTree(treeId, propertyKey);
		this.handleClassifyClick();
	}

	handleTreeSearch(rawValue) {
		const term = rawValue.trim().toLowerCase();
		let activeItem = null;
		this.treeItems.forEach((item) => {
			if (item.dataset.treeId === this.selectedTreeId) {
				activeItem = item;
			}
			const label = item.textContent.trim().toLowerCase();
			const isVisible = term.length === 0 || label.includes(term);
			// .classification-pixie-tree-item sets display: block, which outranks the UA rule for
			// [hidden] -- so the inline style is what hides the item, while the property is the state
			// #setSelectedTree reads back below
			item.hidden = !isVisible;
			item.style.display = isVisible ? "" : "none";
		});

		if (activeItem?.hidden) {
			this.setSelectedTree("");
		}
	}

	buildSelectedClassifications() {
		return Array.from(
			this.resultsContainer.querySelectorAll(
				".classification-checkbox:checked",
			),
		)
			.map((checkbox) => ({
				id: checkbox.dataset.id,
				label: checkbox.dataset.label,
				confidence: checkbox.dataset.confidence,
				reasoning: checkbox.dataset.reasoning,
			}))
			.filter((item) => item.id);
	}

	async setLoadingState(isLoading) {
		if (isLoading) {
			await this.renderLoadingMessage();
			this.setTreeButtonsEnabled(false);
		} else {
			this.setTreeButtonsEnabled(true);
		}
	}

	setTreeButtonsEnabled(isEnabled) {
		this.treeItems.forEach((item) => {
			item.disabled = !isEnabled;
			if (isEnabled) {
				item.removeAttribute("aria-disabled");
			} else {
				item.setAttribute("aria-disabled", "true");
			}
		});
	}

	/**
	 * Both buttons stay hidden until there is a result to act on, and nothing hides them again --
	 * a new run replaces the whole results container.
	 */
	revealActionButtons() {
		if (this.clearSelectionButton) {
			this.clearSelectionButton.style.display = "inline-block";
		}
		if (this.applyButton) {
			this.applyButton.style.display = "inline-block";
		}
		this.updateButtonsState();
	}

	hasSelectedClassifications() {
		return (
			this.resultsContainer.querySelectorAll(".classification-checkbox:checked")
				.length > 0
		);
	}

	handleCheckboxChange(event) {
		if (event.target?.classList?.contains("classification-checkbox")) {
			this.updateButtonsState();
		}
	}

	updateButtonsState() {
		this.setActionButtonsEnabled(this.hasSelectedClassifications());
	}

	setActionButtonsEnabled(isEnabled) {
		if (this.clearSelectionButton) {
			this.clearSelectionButton.disabled = !isEnabled;
		}
		if (this.applyButton) {
			this.applyButton.disabled = !isEnabled;
		}
	}

	handleClear() {
		Array.from(
			this.resultsContainer.querySelectorAll(".classification-checkbox"),
		).forEach((checkbox) => {
			checkbox.checked = false;
		});
		this.updateButtonsState();
	}

	async handleApplyClassifications() {
		const contentId = this.applyButton?.dataset.contentId || "";
		const classificationTreeId =
			this.applyButton?.dataset.classificationTreeId || "";
		const propertyKey = this.applyButton?.dataset.propertyKey || "";

		if (!contentId || !classificationTreeId) {
			await this.renderApplyMessage(
				await this.t(
					"frontend.classification_pixie.apply_missing_data",
					"Missing data for applying classifications.",
				),
				true,
			);
			return;
		}

		const selectedClassifications = this.buildSelectedClassifications();
		if (!selectedClassifications.length) {
			await this.renderApplyMessage(
				await this.t(
					"frontend.classification_pixie.apply_select_one",
					"Select at least one classification to apply.",
				),
				true,
			);
			return;
		}

		const loadingText = await this.t("common.loading", "Loading ...");
		const loadingHtml = `<i class="fa fa-spinner fa-spin" aria-hidden="true"></i> ${loadingText}`;
		DataCycle.disableElement(this.applyButton, loadingHtml);

		try {
			const payload = await DataCycle.httpRequest(
				`/things/${encodeURIComponent(contentId)}/apply_classifications`,
				{
					method: "POST",
					body: {
						classification_tree_id: classificationTreeId,
						property_key: propertyKey,
						content_classifications: {
							content_id: contentId,
							classifications: selectedClassifications,
						},
					},
				},
			);

			if (payload.error) {
				const errorMessage =
					typeof payload.error === "string"
						? payload.error
						: payload.error.message || JSON.stringify(payload.error);
				await this.renderApplyMessage(errorMessage, true);
				this.setActionButtonsEnabled(false);
				return;
			}

			window.location.reload();
		} catch (error) {
			await this.renderApplyMessage(
				await PixieHelpers.errorMessage(
					error,
					"frontend.classification_pixie.apply_failed",
				),
				true,
			);
			this.setActionButtonsEnabled(false);
		} finally {
			if (this.applyButton) {
				DataCycle.enableElement(this.applyButton);
				this.updateButtonsState();
			}
		}
	}

	async handleClassifyClick() {
		const contentId = this.form?.dataset.contentId || "";
		const classificationTreeId = this.selectedTreeId || "";
		const cachedSuggestions = this.resultsCache.get(classificationTreeId);

		if (cachedSuggestions) {
			await this.renderClassifierResults(cachedSuggestions, {
				contentId: contentId,
				classificationTreeId: classificationTreeId,
				propertyKey: this.selectedPropertyKey,
			});
			return;
		}

		await this.setLoadingState(true);

		if (!contentId) {
			this.setLoadingState(false);
			await this.renderClassifierError(
				await this.t(
					"frontend.classification_pixie.missing_content_id",
					"Missing content id for classification request.",
				),
			);
			this.revealActionButtons();
			return;
		}

		if (!classificationTreeId) {
			this.setLoadingState(false);
			await this.renderClassifierError(
				await this.t(
					"frontend.classification_pixie.select_tree",
					"Please select a classification tree.",
				),
			);
			this.revealActionButtons();
			return;
		}

		try {
			const payload = await DataCycle.httpRequest(
				`/things/${encodeURIComponent(contentId)}/classify`,
				{
					method: "POST",
					body: {
						classification_tree_id: classificationTreeId,
					},
				},
			);

			if (payload.error) {
				const errorMessage =
					typeof payload.error === "string"
						? payload.error
						: payload.error.message || JSON.stringify(payload.error);
				await this.renderClassifierError(errorMessage);
				this.revealActionButtons();
				return;
			}

			const suggestions = Array.isArray(payload.suggestions)
				? payload.suggestions
				: [];
			this.resultsCache.set(classificationTreeId, suggestions);
			await this.renderClassifierResults(suggestions, {
				contentId: contentId,
				classificationTreeId: classificationTreeId,
				propertyKey: this.selectedPropertyKey,
			});
		} catch (error) {
			await this.renderClassifierError(
				await PixieHelpers.errorMessage(
					error,
					"frontend.classification_pixie.classify_failed",
				),
			);
			this.revealActionButtons();
			if (this.applyButton) this.applyButton.style.display = "none";
		} finally {
			await this.setLoadingState(false);
		}
	}
}

export default ClassificationPixie;
