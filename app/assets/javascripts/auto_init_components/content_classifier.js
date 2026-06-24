class ContentClassifier {
	static selector = ".content-classifier-form";
	static className = "dcjs-content-classifier";
	constructor(content) {
		this.reveal = content.closest(".reveal");
		this.form = content;
		this.resultsContainer = this.form?.querySelector(".classification-results");
		this.applyButton = this.form?.querySelector(
			".apply-classifications-button",
		);
		this.clearSelectionButton = this.form?.querySelector(".clear-button");
		this.searchInput = this.form?.querySelector(".content-classifier-tree-search");
		this.treeItems = Array.from(
			this.form?.querySelectorAll(".content-classifier-tree-item") || [],
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

	resolveErrorMessage(error, fallbackMessage) {
		return (
			error?.responseBody?.error ||
			error?.responseJSON?.error ||
			error?.message ||
			fallbackMessage
		);
	}

	async renderClassifierError(message) {
		const title = await this.t(
			"frontend.content_classifier.classification_error_title",
			"Classification Error",
		);
		this.resultsContainer.innerHTML = `
			<div class="callout alert">
				<h4>${title}</h4>
				<p style="margin: 0.5rem 0;">${message}</p>
			</div>
		`;
	}

	async renderApplyMessage(message, isError) {
		const typeClass = isError ? "alert" : "success";
		const title = isError
			? await this.t(
					"frontend.content_classifier.apply_error_title",
					"Apply Error",
				)
			: await this.t(
					"frontend.content_classifier.applied_title",
					"Classifications Applied",
				);

		this.resultsContainer.innerHTML = `
			<div class="callout ${typeClass}">
				<h4>${title}</h4>
				<p style="margin: 0.5rem 0;">${message}</p>
			</div>
		`;
	}

	async renderClassifierResults(suggestions, details, options = {}) {
		const resultsTitle = await this.t(
			"frontend.content_classifier.results_title",
			"Classification Results",
		);
		const unknownLabel = await this.t(
			"frontend.content_classifier.unknown_label",
			"Unknown",
		);
		const notAvailable = await this.t(
			"frontend.content_classifier.not_available",
			"n/a",
		);
		const noClassifications = await this.t(
			"frontend.content_classifier.no_classifications",
			"No classifications returned.",
		);
		const summaryText = suggestions.length
			? await this.t(
					"frontend.content_classifier.classifications_suggested",
					"%{count} classifications suggested.",
					{ count: suggestions.length },
				)
			: "";

		const listItems = suggestions
			.map((item, index) => {
				const idValue = item.id || "";
				const label = item.label || item.id || unknownLabel;
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
				const confidenceBarClass = hasConfidence ? confidenceLevelClass : "";
				const reasoning = item.reasoning
					? `<p class="content-classifier-suggestion-reasoning">${item.reasoning}</p>`
					: "";
				const inputId = `classification_${details.contentId}_${index}`;
				return `
					<li class="content-classifier-suggestion">
						<label class="content-classifier-suggestion-label" for="${inputId}">
							<input
								type="checkbox"
								id="${inputId}"
								class="classification-checkbox"
								data-id="${idValue}"
								data-label="${label}"
								data-confidence="${confidenceValue}"
								data-reasoning="${item.reasoning || ""}"
								checked
							/>
							<span class="content-classifier-suggestion-text">
								<span class="content-classifier-suggestion-title">${label}</span>
								<span class="content-classifier-suggestion-confidence${confidenceClass}">${confidenceText}</span>
							</span>
						</label>
						<div class="content-classifier-suggestion-bar" aria-hidden="true">
							<span class="content-classifier-suggestion-bar-fill${confidenceBarClass}" ${confidenceBarStyle}></span>
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
			: `<li class="content-classifier-suggestion empty">${emptyMessage}</li>`;
		this.resultsContainer.innerHTML = `
			<div class="content-classifier-results">
				<div class="content-classifier-results-header">
					<h4>${resultsTitle}</h4>
					${summaryMarkup}
				</div>
				<ul class="content-classifier-suggestions">
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

		this.setResultsState(true);
	}

	async renderLoadingMessage() {
		const loadingText = await this.t("common.loading", "Loading...");
		this.resultsContainer.innerHTML = `
			<div class="content-classifier-results content-classifier-loading">
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

	setResultsState() {
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
					"frontend.content_classifier.apply_missing_data",
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
					"frontend.content_classifier.apply_select_one",
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
				this.resolveErrorMessage(
					error,
					await this.t(
						"frontend.content_classifier.apply_failed",
						"Failed to apply classifications.",
					),
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
					"frontend.content_classifier.missing_content_id",
					"Missing content id for classification request.",
				),
			);
			this.setResultsState(true);
			return;
		}

		if (!classificationTreeId) {
			this.setLoadingState(false);
			await this.renderClassifierError(
				await this.t(
					"frontend.content_classifier.select_tree",
					"Please select a classification tree.",
				),
			);
			this.setResultsState(true);
			return;
		}

		try {
			const payload = await DataCycle.httpRequest(
				`/things/${encodeURIComponent(contentId)}/classify`,
				{
					method: "POST",
					body: {
						classification_tree_id: classificationTreeId,
						// endpoint_id: this.endpointId,
					},
				},
			);

			if (payload.error) {
				const errorMessage =
					typeof payload.error === "string"
						? payload.error
						: payload.error.message || JSON.stringify(payload.error);
				await this.renderClassifierError(errorMessage);
				this.setResultsState(true);
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
				// endpointId: this.endpointId,
			});
		} catch (error) {
			await this.renderClassifierError(
				this.resolveErrorMessage(
					error,
					await this.t(
						"frontend.content_classifier.classify_failed",
						"Failed to fetch classifications.",
					),
				),
			);
			this.setResultsState(true);
			if (this.applyButton) this.applyButton.style.display = "none";
		} finally {
			await this.setLoadingState(false);
		}
	}
}

export default ContentClassifier;
