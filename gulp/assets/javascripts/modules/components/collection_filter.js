class CollectionFilter {
  constructor(selector) {
    this.selector = $(selector);
    this.filterInput = this.selector.find('.watch-lists-filter .watch-list-filter-param');
    this.filterResetButton = this.selector.find('.watch-lists-filter .reset-watch-list-filter');
    this.collection = this.selector.find('.list-items');
    this.newForm = this.selector.find('.add-watchlist .add-watchlist-form');
    this.filterInputTimeout = null;

    this.init();
  }
  init() {
    this.filterInput.on('input', this.checkTimeout.bind(this));
    this.filterResetButton.on('click', this.resetFilter.bind(this));
    this.selector.on('dc:collection:filter', this.setFilterInputValue.bind(this));
    this.newForm.on('dc:collection:newCollection', this.addNewCollection.bind(this));
  }
  checkTimeout(event) {
    event.preventDefault();

    if (this.filterInputTimeout !== null) {
      clearTimeout(this.filterInputTimeout);
    }
    this.filterInputTimeout = setTimeout(() => {
      this.filterCollection();
    }, 500);
  }
  resetFilter(event) {
    event.preventDefault();

    this.filterInput.val(null);
    this.syncFilterInputs(null);
    this.filterCollection();
  }
  filterCollection() {
    $.rails.disableFormElement(this.filterResetButton);
    let q = (this.filterInput.val() || '').trim().toLowerCase();

    this.toggleResetButton(q.length > 0);
    this.collection.trigger('dc:remote:reload', { options: { q: q } });

    $.rails.enableFormElement(this.filterResetButton);
    this.syncFilterInputs(q);
  }
  syncFilterInputs(q) {
    $('.dropdown-pane.watch-lists').not(this.selector).trigger('dc:collection:filter', { q: q });
  }
  toggleResetButton(show) {
    if (show && this.filterResetButton.is(':hidden')) {
      this.filterResetButton.fadeIn(100);
    } else if (!show && !this.filterResetButton.is(':hidden')) {
      this.filterResetButton.fadeOut(100);
    }
  }
  setFilterInputValue(event, data) {
    event.stopPropagation();

    let filterValue = data && data.q;
    this.filterInput.val(filterValue);
    this.toggleResetButton(filterValue && filterValue.length > 0);

    this.collection.trigger('dc:remote:reloadOnNextOpen', { q: filterValue });
  }
  addNewCollection(event) {
    this.newForm.find(':text').val(null);
    this.filterCollection();
    $('.dropdown-pane.watch-lists .list-items').not(this.collection).trigger('dc:remote:reloadOnNextOpen');
  }
}

module.exports = CollectionFilter;