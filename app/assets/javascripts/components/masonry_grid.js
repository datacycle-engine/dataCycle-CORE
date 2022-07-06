import ObserverHelpers from '../helpers/observer_helpers';

class MasonryGrid {
  constructor(selector, config = null) {
    this.grid = $(selector);
    this.rowHeight = parseInt(window.getComputedStyle(this.grid[0]).getPropertyValue('grid-auto-rows'));
    this.config = config || { attributes: true, childList: true, subtree: true };
    this.observer = new MutationObserver(this.callbackFunction.bind(this));
    this.addedItemsObserver = new MutationObserver(this._checkForAddedNodes.bind(this));

    if (this.checkSupport()) this.setup();
    else this.renderNotSupportedError();
  }
  setup() {
    this.grid.children('.grid-loading').remove();
    this.grid.children('.grid-item').each((_index, item) => this.initializeItem(item));

    $(window).on('load resize', this.resizeAllMasonryItems.bind(this));

    this.addedItemsObserver.observe(this.grid[0], ObserverHelpers.newItemsConfig);
  }
  checkSupport() {
    let el = document.createElement('div');
    return typeof el.style.grid === 'string';
  }
  renderNotSupportedError() {
    $('body').append(
      '<div class="html-feature-missing"><h2>Verwenden Sie bitte einen aktuellen Browser um diese Anwendung korrekt darstellen zu können!</h2></div>'
    );
  }
  _checkForAddedNodes(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'childList') continue;

      for (const addedNode of mutation.addedNodes) {
        if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;

        ObserverHelpers.checkForConditionRecursive(
          addedNode,
          e => e.classList.contains('grid-item'),
          this.initializeItem.bind(this)
        );
      }
    }
  }
  initializeItem(item) {
    item.style.display = 'block';
    this.resizeMasonryItem(item);
    this.observer.observe(item, this.config);
  }
  callbackFunction(mutationsList, _observer) {
    for (const mutation of mutationsList) {
      let item = $(mutation.target).closest('.grid-item');
      if (
        item.length &&
        !mutation.target.closest('.watch-lists') &&
        !mutation.target.closest('.watch-lists-link') &&
        this.heightChanged(item)
      ) {
        this.resizeMasonryItem(item[0]);
      }
    }
  }
  boundingHeight(item) {
    return item.querySelector('.content-link') === null
      ? item.getBoundingClientRect().height
      : item.querySelector('.content-link').getBoundingClientRect().height;
  }
  resizeMasonryItem(item) {
    let newHeight = this.boundingHeight(item);
    $(item).data('original-height', newHeight);
    let rowSpan = Math.ceil(newHeight / this.rowHeight) + 1;
    item.style.gridRow = 'span ' + rowSpan;
  }
  resizeAllMasonryItems(event) {
    this.grid[0].querySelectorAll(':scope .grid-item').forEach(item => {
      this.resizeMasonryItem(item);
    });
  }
  heightChanged(item) {
    return $(item).data('original-height') !== this.boundingHeight(item[0]);
  }
}

export default MasonryGrid;
