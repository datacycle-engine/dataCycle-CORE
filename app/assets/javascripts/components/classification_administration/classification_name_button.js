class ClassificationNameButton {
	constructor(item) {
		this.item = item;
		this.childrenContainer = this.item
			.closest("li")
			.querySelector(":scope > ul.children");

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.toggleChildren.bind(this));
	}
	toggleChildren(event) {
		event.preventDefault();
		event.stopPropagation();

		this.item.classList.toggle("open");
		this.childrenContainer.classList.toggle("open");

		if (!this.item.classList.contains("loaded")) this.loadChildren();
	}
	loadChildren() {
		DataCycle.disableElement(this.item);
		this.childrenContainer.innerHTML = "";

		DataCycle.httpRequest(this.item.href)
			.then((data) => {
				if (data?.html) this.childrenContainer.innerHTML = data.html;

				this.item.classList.add("loaded");
			})
			.finally(() => {
				DataCycle.enableElement(this.item);
			});
	}
}

export default ClassificationNameButton;
