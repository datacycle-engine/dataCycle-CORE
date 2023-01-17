class ShowMoreLinkToggler {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-show-more-link-toggler');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.toggle.bind(this));
  }
  toggle(event) {
    event.preventDefault();
    event.stopPropagation();

    this.item.parentElement.classList.toggle('active');
    this.item.parentElement.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  }
}

export default ShowMoreLinkToggler;
