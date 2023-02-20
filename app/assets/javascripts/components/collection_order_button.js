import CalloutHelpers from '../helpers/callout_helpers';
import { Sortable } from 'sortablejs';

class CollectionOrderButton {
  constructor(button) {
    this.item = button;
    this.item.classList.add('dcjs-collection-order-button');
    this.itemWrapper = this.item.closest('.collection-manual-order-container ');
    this.sortableList = document.getElementById('search-results').querySelector('ul');
    this.sortable = new Sortable(this.sortableList, {
      forceAutoScrollFallback: true,
      scrollSpeed: 50,
      group: 'manual-collection-order',
      handle: '.draggable-handle',
      draggable: 'li.list-item',
      disabled: true,
      onEnd: this.updateOrder.bind(this)
    });
    this.handleHtml = '<span class="draggable-handle"><i class="fa fa-bars" aria-hidden="true"></i></span>';
    this.newButtonObserver = new MutationObserver(this._observeHtmlContent.bind(this));
    this.observerConfig = {
      attributes: false,
      characterData: false,
      subtree: true,
      childList: true,
      attributeOldValue: false,
      characterDataOldValue: false
    };

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.toggleSortable.bind(this));
  }
  toggleSortable(event) {
    event.preventDefault();

    if (this.itemWrapper.classList.contains('active')) this.disableSortable();
    else this.enableSortable();
  }
  addDraggableHandle(item) {
    item.querySelector(':scope > .inner-item').insertAdjacentHTML('afterbegin', this.handleHtml);
  }
  enableSortable() {
    this.itemWrapper.classList.add('active');

    for (const item of this.sortableList.querySelectorAll('li.list-item')) this.addDraggableHandle(item);

    this.newButtonObserver.observe(this.sortableList, this.observerConfig);

    this.sortable.option('disabled', false);
  }
  disableSortable() {
    this.itemWrapper.classList.remove('active');

    for (const item of this.sortableList.querySelectorAll('.draggable-handle')) item.remove();

    this.newButtonObserver.disconnect();

    this.sortable.option('disabled', true);
  }
  updateOrder(event) {
    if (event.from === event.to && event.oldIndex === event.newIndex) return;

    const element = event.item;
    this.disableElement(element);

    DataCycle.httpRequest({
      url: this.item.dataset.url,
      method: 'patch',
      dataType: 'json',
      data: {
        order: this.sortable.toArray()
      }
    })
      .then(data => {
        if (data && data.error) CalloutHelpers.show(data.error, 'alert');
        if (data && data.success) CalloutHelpers.show(data.success, 'success');
      })
      .catch(() => {
        I18n.t('collection.manual_order.error').then(text => CalloutHelpers.show(text, 'alert'));
      })
      .finally(() => {
        this.enableElement(element);
      });
  }
  enableElement(e) {
    e.classList.remove('saving-order');
  }
  disableElement(e) {
    e.classList.add('saving-order');
  }
  _observeHtmlContent(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'childList') continue;

      for (const addedNode of mutation.addedNodes) {
        if (
          addedNode.nodeName === 'LI' &&
          addedNode.classList.contains('list-item') &&
          !addedNode.querySelector('.draggable-handle')
        )
          this.addDraggableHandle(addedNode);
      }
    }
  }
}

export default CollectionOrderButton;
