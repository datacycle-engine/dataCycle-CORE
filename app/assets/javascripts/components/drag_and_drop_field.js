class DragAndDropField {
	constructor(container) {
		container.classList.add("dcjs-drag-and-drop-field");
		this.container = $(container);
		this.uploaderRevealId = this.container.data("asset-uploader");
		this.uploaderReveal = $(`#${this.container.data("asset-uploader")}`);
		this.fileField = this.container.find("input.content-upload-field");

		this.init();
	}
	init() {
		if (!this.isAdvancedUpload) return;
		if (!this.fileField.length)
			this.fileField = this.uploaderReveal.find(
				'input[type="file"].upload-file',
			);

		this.initDragAndDropEvents(
			this.container[0].querySelector(".drag-and-drop-field"),
		);
		if (this.uploaderReveal.length)
			for (const field of this.uploaderReveal[0].querySelectorAll(
				".drag-and-drop-field",
			))
				this.initDragAndDropEvents(field);

		this.fileField.on("change", (e) => {
			e.preventDefault();
			e.stopPropagation();

			this.openUploaderReveal(e.target.files);
		});
	}
	initDragAndDropEvents(field) {
		if (!field) return;

		for (const type of [
			"drag",
			"dragstart",
			"dragend",
			"dragover",
			"dragenter",
			"dragleave",
			"drop",
		])
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

			this.fileField.trigger("click");
		});
	}
	openUploaderReveal(files) {
		$(`#${this.uploaderRevealId}`)
			.trigger("dc:upload:setFiles", { fileList: files })
			.foundation("open");
	}
	isAdvancedUpload() {
		var div = document.createElement("div");
		return (
			("draggable" in div || ("ondragstart" in div && "ondrop" in div)) &&
			"FormData" in window &&
			"FileReader" in window
		);
	}
}

export default DragAndDropField;
