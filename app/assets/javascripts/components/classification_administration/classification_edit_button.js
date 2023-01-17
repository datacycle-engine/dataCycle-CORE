class ClassificationEditButton {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-classification-edit-button');
    this.container = document.getElementById('classification-administration');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.showForm.bind(this));
  }
  showForm(event) {
    event.preventDefault();
    event.stopPropagation();

    for (const li of this.container.querySelectorAll('li.active')) li.classList.remove('active');

    this.item.closest('li').classList.add('active');
  }
}

export default ClassificationEditButton;
