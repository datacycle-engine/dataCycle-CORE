// Masonry Grid View
class MasonryGrid {
  constructor(selector, config = null) {
    this.grid = $(selector);
    this.rowGap = parseInt(window.getComputedStyle(this.grid[0]).getPropertyValue('grid-row-gap'));
    this.rowHeight = parseInt(window.getComputedStyle(this.grid[0]).getPropertyValue('grid-auto-rows'));
    this.config = config || { attributes: true, childList: true, subtree: true };
    this.observer = new MutationObserver(this.callbackFunction.bind(this));

    if (this.checkSupport()) this.setup();
    else this.renderNotSupportedError();
  }
  setup() {
    this.grid.children('.grid-loading').hide();
    this.grid
      .children('.grid-item')
      .get()
      .forEach(item => {
        item.style.display = 'block';
        this.resizeMasonryItem(item);
        this.observer.observe(item, this.config);
      });

    $(window).on('load resize', this.resizeAllMasonryItems.bind(this));
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
  callbackFunction(mutationsList, _observer) {
    for (var mutation of mutationsList) {
      let item = $(mutation.target).closest('.grid-item');
      if (
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
    let rowSpan = Math.round((newHeight + this.rowGap) / (this.rowHeight + this.rowGap));
    item.style.gridRowEnd = 'span ' + rowSpan;
  }
  resizeAllMasonryItems(event) {
    this.grid[0].querySelectorAll('.grid-item').forEach(item => {
      this.resizeMasonryItem(item);
    });
  }
  heightChanged(item) {
    return $(item).data('original-height') !== this.boundingHeight(item[0]);
  }
}

module.exports = MasonryGrid;
