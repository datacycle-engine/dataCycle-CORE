import DomElementHelper from "../helpers/dom_element_helpers";

class ContentScore {
	constructor(element) {
		this.element = element;
		this.contentScoreText = this.element.querySelector(".content-score-text");
		this.container = this.element.closest(
			".form-element, .detail-property, .detail-type, #edit-form, .detail-header, .embedded-object > .content-object-item, .detail-header > .title",
		);
		this.stylingContainerMapping = {
			"#edit-form": ":scope > .edit-header",
			".detail-type":
				":scope > .detail-label, :scope > .map-info > .detail-label",
			".form-element": ".attribute-edit-label",
		};
		this.stylingContainer = this.getStylingContainer();
		this.contentId = this.element.dataset.contentScoreContentId;
		this.contentEmbedded = DomElementHelper.parseDataAttribute(
			this.element.dataset.contentScoreEmbedded,
		);
		this.template = this.element.dataset.contentScoreTemplate;
		this.attributeKey = this.element.dataset.key;
		this.locale = this.element.dataset.locale;

		this.setup();
	}
	getStylingContainer() {
		for (const [k, v] of Object.entries(this.stylingContainerMapping)) {
			if (this.container.matches(k)) {
				return this.container.querySelector(v);
			}
		}

		return this.container;
	}
	setup() {
		if (this.stylingContainer)
			this.stylingContainer.classList.add("dc-content-score");
		$(this.container).on("change", this.loadScore.bind(this)); // not yet working with native 'change' event

		this.loadScore();
	}
	loadScore() {
		if (!this.container) return;

		this.element.classList.add("score-loading");

		const formData = DomElementHelper.getFormData(
			this.container,
			"thing[",
			this.contentEmbedded,
		);
		const url = "/things/content_score";

		if (this.template) formData.set("template_name", this.template);
		if (this.attributeKey) formData.set("attribute_key", this.attributeKey);
		if (this.contentId) formData.set("id", this.contentId);
		if (this.locale) formData.set("locale", this.locale);

		DataCycle.httpRequest(url, { method: "POST", body: formData })
			.then(this.setNewScore.bind(this))
			.catch((_e) => {
				this.stylingContainer.removeAttribute("data-content-score");
				this.contentScoreText.innerHTML = "";
				this.updateTooltip();
			})
			.finally(() => {
				this.element.classList.remove("score-loading");
			});
	}
	async updateTooltip(score = undefined) {
		const template = document.createElement("template");
		template.innerHTML = this.element.dataset.dcTooltip;
		const scoreHtml = template.content.querySelector(".tooltip-content-score");

		if (!scoreHtml) return;

		if (score !== undefined) {
			scoreHtml.textContent = await I18n.t(
				"feature.content_score.tooltip_score",
				{ score: score },
			);
		} else scoreHtml.remove();

		this.element.dataset.dcTooltip = template.innerHTML;
	}
	setNewScore(data) {
		if (!Object.hasOwn(data, "value")) return;

		const score = Math.round(data.value * 100);

		this.contentScoreText.innerHTML = score;
		this.stylingContainer.dataset.contentScore = score;
		this.updateTooltip(score);
	}
}

export default ContentScore;
