import { changedClassConfig } from "../helpers/observer_helpers.js";

class ImageDetailEditorBase {
	constructor(button) {
		this.button = button;
		this.imageContainer = this.button
			.closest(".image")
			?.querySelector(".thumb");

		this.editingObserver = new MutationObserver(
			this.#checkForOtherEditing.bind(this),
		);

		this.initBase();
	}

	initBase() {
		this.editingObserver.observe(this.imageContainer, changedClassConfig);
		this.button.addEventListener("click", this.click.bind(this));
	}

	click(event) {
		event.preventDefault();

		if (this.isEditing()) this.disableEditing();
		else this.enableEditing();
	}

	isEditing() {
		return this.button.classList.contains("editing");
	}

	async enableEditing() {
		this.button.classList.add("editing");
		this.imageContainer.classList.add(
			this.constructor.containerClassName,
			"editing",
		);
		I18n.t(
			`feature.${this.constructor.i18nNameSpace}.editing_button_title`,
		).then((text) => {
			this.button.innerHTML = text;
		});
	}
	async disableEditing() {
		this.button.classList.remove("editing");
		this.imageContainer.classList.remove(
			this.constructor.containerClassName,
			"editing",
		);
		I18n.t(`feature.${this.constructor.i18nNameSpace}.button_title`).then(
			(text) => {
				this.button.innerHTML = text;
			},
		);
	}

	#checkForOtherEditing(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "attributes") continue;

			if (
				!mutation.target.classList.contains(
					this.constructor.containerClassName,
				) &&
				mutation.target.classList.contains("editing")
			) {
				DataCycle.disableElement(this.button);
			} else if (
				!mutation.target.classList.contains(
					this.constructor.containerClassName,
				) &&
				!mutation.target.classList.contains("editing")
			) {
				DataCycle.enableElement(this.button);
			}
		}
	}
}
export default ImageDetailEditorBase;
