import ConfirmationModal from '../confirmation_modal';

class ClassificationDetailToggler {
  constructor(item) {
    this.item = item;
    this.dcClassificationDetailToggler = true;

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.toggleInnerItem.bind(this));
  }
  toggleInnerItem(event) {
    event.preventDefault();
    event.stopPropagation();

    event.currentTarget.closest('.inner-item').classList.toggle('open');
  }
}

export default ClassificationDetailToggler;
