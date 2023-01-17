class ClassificationLoadMoreButton {
  constructor(item) {
    this.item = item;
    this.liElement = this.item.closest('li.load-more-link');
    this.item.classList.add('dcjs-classification-load-more-button');
    this.sibling = this.item.nextElementSibling || this.item.previousElementSibling;

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.loadMore.bind(this));
  }
  loadMore(event) {
    event.preventDefault();
    event.stopPropagation();

    DataCycle.disableElement(this.item);
    if (this.sibling) DataCycle.disableElement(this.sibling, this.sibling.innerHTML);

    DataCycle.httpRequest({
      url: this.item.href,
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        if (data && data.html) this.liElement.insertAdjacentHTML('afterend', data.html);

        this.liElement.remove();
      })
      .finally(() => {
        DataCycle.enableElement(this.item);
        if (this.sibling) DataCycle.enableElement(this.sibling);
      });
  }
}

export default ClassificationLoadMoreButton;
