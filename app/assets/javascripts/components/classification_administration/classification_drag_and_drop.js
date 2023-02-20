import { Sortable } from 'sortablejs';
import CalloutHelpers from '../../helpers/callout_helpers';

class ClassificationDragAndDrop {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-classification-drag-and-drop');
    this.treeLabel = this.item.closest('li.classification_tree_label');
    this.disableButton = this.treeLabel.querySelector(':scope > .inner-item > .classification-order-button');
    this.sortable = new Sortable(this.item, {
      forceAutoScrollFallback: true,
      scrollSpeed: 50,
      group: this.item.classList.contains('move-to-tree')
        ? 'draggable-classification-administration'
        : this.treeLabel.id,
      filter: 'li.new-button, li.mapped',
      preventOnFilter: false,
      handle: '.draggable-handle',
      draggable: 'li.direct, li.new-button, li.mapped',
      disabled: !this.treeLabel.classList.contains('sortable-active'),
      onEnd: this.updateOrder.bind(this),
      onMove: this.checkNewButtonPosition.bind(this)
    });

    this.setup();
  }
  setup() {
    this.disableButton.addEventListener('click', this.toggleSortable.bind(this));
  }
  toggleSortable(event) {
    event.preventDefault();

    if (this.sortable.option('disabled')) this.enableSortable();
    else this.disableSortable();
  }
  disableSortable() {
    this.treeLabel.classList.remove('sortable-active');
    this.sortable.option('disabled', true);
  }
  enableSortable() {
    this.treeLabel.classList.add('sortable-active');
    this.sortable.option('disabled', false);
  }
  updateOrder(event) {
    if (event.from === event.to && event.oldIndex === event.newIndex) return;

    const element = event.item;
    this.disableElement(element);

    this.sendUpdateRequest({
      classificationAliasId: element.dataset.id,
      classificationTreeLabelId: element.closest('li.classification_tree_label').id,
      previousAliasId: element.previousElementSibling && element.previousElementSibling.dataset.id,
      newParentAliasId:
        element.parentElement.closest('li.direct') && element.parentElement.closest('li.direct').dataset.id
    }).finally(() => this.enableElement(element));
  }
  enableElement(e) {
    e.classList.remove('saving-order');
  }
  disableElement(e) {
    e.classList.add('saving-order');
  }
  sendUpdateRequest(data) {
    return DataCycle.httpRequest({
      url: '/classifications/move',
      method: 'patch',
      dataType: 'json',
      data: data
    })
      .then(data => {
        if (data && data.error) CalloutHelpers.show(data.error, 'alert');
        if (data && data.success) CalloutHelpers.show(data.success, 'success');
      })
      .catch(() => I18n.t('classification_administration.move.error').then(text => CalloutHelpers.show(text, 'alert')));
  }
  checkNewButtonPosition(event) {
    if (event.related.classList.contains('mapped') || event.related.classList.contains('new-button'))
      return event.related.previousElementSibling && !event.related.previousElementSibling.classList.contains('direct')
        ? false
        : -1;

    return true;
  }
}

export default ClassificationDragAndDrop;
