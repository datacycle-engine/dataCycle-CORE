import { changedClassConfig } from "../helpers/observer_helpers.js";

class FocusPointEditor {
	static selector = ".change-focus-point-ui";
	static className = "dcjs-focus-point-editor";
	static lazy = true;
	constructor(element) {
		this.element = element;
		this.imageContainer = this.element
			.closest(".image")
			?.querySelector(".thumb");
		this.editingObserver = new MutationObserver(
			this.#checkForAnotherEditing.bind(this),
		);

		this.init();
	}
	init() {
		this.element.addEventListener("click", this.click.bind(this));
		this.editingObserver.observe(this.imageContainer, changedClassConfig);
	}
	#checkForAnotherEditing(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "attributes") continue;

			if (
				!mutation.target.classList.contains("focus-point-ui") &&
				mutation.target.classList.contains("editing") &&
				(!mutation.oldValue || mutation.oldValue.includes("remote-rendering"))
			)
				this.triggerSyncWithContentUploader();
		}
	}
	click(event) {
		event.preventDefault();

		if (this.isEditing()) this.disableEditing();
		else this.enableEditing();

		// if (this.element.dataset.href) {
		// 	const url = `${DataCycle.config.EnginePath}/things/${this.element.dataset.href}`;
		// 	window.open(url, "_blank");
		// }
	}
	isEditing() {
		return this.element.classList.contains("editing");
	}
	async enableEditing() {
		this.element.classList.add("editing");
		this.imageContainer.classList.add("focus-point-ui", "editing");
		I18n.t("feature.focus_point_editor.editing_button_title").then((text) => {
			this.element.innerHTML = text;
		});
		// Add logic to enable focus point editing, e.g., show a grid or markers
	}
	async disableEditing() {
		this.element.classList.remove("editing");
		this.imageContainer.classList.remove("focus-point-ui", "editing");
		I18n.t("feature.focus_point_editor.button_title").then((text) => {
			this.element.innerHTML = text;
		});
	}
}

export default FocusPointEditor;
