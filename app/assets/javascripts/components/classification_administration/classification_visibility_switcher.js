class ClassificationVisibilitySwitcher {
  constructor(item) {
    this.item = item;
    this.checkboxContainer = this.item.closest('.ca-collection-checkboxes');
    this.item.classList.add('dcjs-classification-visibility-switcher');
    this.siblingValue = this.item.value == 'show_more' ? 'show' : 'show_more';

    this.setup();
  }
  setup() {
    this.item.addEventListener('change', this.switchVisibilitiesInForm.bind(this));
  }
  switchVisibilitiesInForm(_event) {
    if (!this.item.checked) return;

    const sibling = this.checkboxContainer.querySelector(
      `[name="classification_tree_label[visibility][]"][value="${this.siblingValue}"]`
    );

    if (sibling) sibling.checked = false;
  }
}

export default ClassificationVisibilitySwitcher;
