import { changedClassConfig } from "../helpers/observer_helpers.js";

class ImageDetailEditorBase {
	static icon = "fa-pencil";
	static editingIcon = "fa-check";

	/**
	 * Label of the button while it is idle, and while it is editing. Separate from
	 * +i18nNameSpace+ so an editor whose keys do not follow it can name them instead of
	 * overriding enableEditing to relabel the button after the fact.
	 *
	 * +this+ is the subclass the getter is read on, which is where +i18nNameSpace+ is declared:
	 * naming the base class here instead resolves to undefined, and the button asks for
	 * feature.undefined.editing_button_title.
	 */
	static get titleKey() {
		return `feature.${this.i18nNameSpace}.button_title`;
	}

	static get editingTitleKey() {
		return `feature.${this.i18nNameSpace}.editing_button_title`;
	}

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
		this.renderButtonLabel(
			this.constructor.editingTitleKey,
			this.constructor.editingIcon,
		);
	}

	async disableEditing() {
		this.button.classList.remove("editing");
		this.imageContainer.classList.remove(
			this.constructor.containerClassName,
			"editing",
		);
		this.renderButtonLabel(this.constructor.titleKey, this.constructor.icon);
	}

	renderButtonLabel(key, icon) {
		I18n.t(key).then((text) => {
			this.button.innerHTML = `<i class="fa ${icon}" aria-hidden="true"></i>${text}`;
		});
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
