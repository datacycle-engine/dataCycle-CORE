class ClassificationNameButton {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-classification-name-button');
    this.childrenContainer = this.item.closest('li').querySelector(':scope > ul.children');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.toggleChildren.bind(this));
  }
  toggleChildren(event) {
    event.preventDefault();
    event.stopPropagation();

    this.item.classList.toggle('open');
    this.childrenContainer.classList.toggle('open');

    if (!this.item.classList.contains('loaded')) this.loadChildren();
  }
  loadChildren() {
    DataCycle.disableElement(this.item);
    this.childrenContainer.innerHTML = '';

    DataCycle.httpRequest({
      url: this.item.href,
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        if (data && data.html) this.childrenContainer.innerHTML = data.html;

        this.item.classList.add('loaded');
      })
      .finally(() => {
        DataCycle.enableElement(this.item);
      });
  }
}

export default ClassificationNameButton;
