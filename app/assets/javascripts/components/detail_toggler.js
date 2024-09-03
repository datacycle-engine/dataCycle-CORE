class DetailToggler {
	constructor(item) {
		this.item = item;

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.toggleInnerItem.bind(this));
	}
	toggleInnerItem(event) {
		event.preventDefault();
		event.stopPropagation();

		this.item.closest(".inner-item").classList.toggle("open");
	}
}

export default DetailToggler;
