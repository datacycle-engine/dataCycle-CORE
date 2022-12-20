import ObserverHelpers from '../../helpers/observer_helpers';

class ClassificationLoadAllButton {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-classification-load-all-button');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.loadAllChildren.bind(this));
  }
  loadAllChildren(event) {
    event.preventDefault();
    event.stopPropagation();

    this.loadDirectChildren(this.item.closest('li').querySelector(':scope > span.inner-item > a.name'));
  }
  loadDirectChildren(element) {
    if (element.classList.contains('loaded')) {
      const children = element.closest('li').querySelector(':scope > ul.children');

      if (children.querySelectorAll(':scope > li:not(.new-button)').length) {
        if (!element.classList.contains('open')) element.click();

        this.showChildrenRecursive(element);
      }
    } else {
      const observer = new MutationObserver(this.newChildrenCallback.bind(this));
      observer.observe(element.closest('li').querySelector(':scope > ul.children'), ObserverHelpers.newItemsConfig);

      const classObserver = new MutationObserver(this.loadedObserverCallback.bind(this, observer));
      classObserver.observe(element, ObserverHelpers.changedClassConfig);

      if (!element.classList.contains('open')) element.click();
    }
  }
  newChildrenCallback(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'childList') continue;

      for (const addedNode of mutation.addedNodes) {
        if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;

        ObserverHelpers.checkForConditionRecursive(
          addedNode,
          e => e.classList.contains('dcjs-classification-name-button'),
          this.loadDirectChildren.bind(this)
        );
      }
    }
  }
  loadedObserverCallback(newChildrenObserver, mutations, observer) {
    for (const mutation of mutations) {
      if (mutation.type !== 'attributes') continue;

      if (
        mutation.target.classList.contains('loaded') &&
        (!mutation.oldValue || mutation.oldValue.includes('loaded'))
      ) {
        observer.disconnect();
        newChildrenObserver.disconnect();

        this.hideChildrenIfEmpty(mutation.target);
      }
    }
  }
  hideChildrenIfEmpty(element) {
    const children = element.closest('li').querySelector(':scope > ul.children');

    if (!children.querySelectorAll(':scope > li:not(.new-button)').length) element.click();
  }
  showChildrenRecursive(element) {
    for (const child of element.closest('li').querySelectorAll(':scope > ul.children > li > span.inner-item > .name'))
      this.loadDirectChildren(child);
  }
}

export default ClassificationLoadAllButton;
