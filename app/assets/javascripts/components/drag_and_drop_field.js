class DragAndDropField {
	constructor(container) {
		this.container = container;
		this.uploaderRevealId = this.container.dataset.assetUploader;
		this.uploaderReveal = document.getElementById(this.uploaderRevealId);
		this.fileField = this.container.querySelector("input.content-upload-field");
		this.dragEvents = [
			"drag",
			"dragstart",
			"dragend",
			"dragover",
			"dragenter",
			"dragleave",
			"drop",
		];

		this.init();
	}
	init() {
		if (!this.isAdvancedUpload) return;
		if (!this.fileField)
			this.fileField = this.uploaderReveal.querySelector(
				'input[type="file"].upload-file',
			);

		this.initDragAndDropEvents(
			this.container.querySelector(".drag-and-drop-field"),
		);

		if (this.uploaderReveal) {
			for (const field of this.uploaderReveal.querySelectorAll(
				".drag-and-drop-field",
			)) {
				this.initDragAndDropEvents(field);
			}
		}

		this.fileField.addEventListener("change", (e) => {
			e.preventDefault();
			e.stopPropagation();

			this.openUploaderReveal(e.target.files);
		});
	}
	initDragAndDropEvents(field) {
		if (!field || field.classList.contains("dcjs-drag-and-drop")) return;

		field.classList.add("dcjs-drag-and-drop");

		for (const type of this.dragEvents)
			field.addEventListener(type, (e) => {
				e.preventDefault();
				e.stopPropagation();
			});

		for (const type of ["dragenter", "dragover"])
			field.addEventListener(type, (_e) => {
				field.classList.add("is-dragover");
			});

		for (const type of ["dragleave", "dragend", "drop"])
			field.addEventListener(type, (_e) => {
				field.classList.remove("is-dragover");
			});

		field.addEventListener("drop", (e) => {
			this.openUploaderReveal(e.dataTransfer.files);
		});

		field.addEventListener("click", (e) => {
			e.preventDefault();
			e.stopPropagation();

			$(this.fileField).trigger("click");
		});
	}
	openUploaderReveal(files) {
		$(`#${this.uploaderRevealId}`)
			.trigger("dc:upload:setFiles", { fileList: files })
			.foundation("open");
	}
	isAdvancedUpload() {
		const div = document.createElement("div");
		return (
			("draggable" in div || ("ondragstart" in div && "ondrop" in div)) &&
			"FormData" in window &&
			"FileReader" in window
		);
	}
}

export default DragAndDropField;
