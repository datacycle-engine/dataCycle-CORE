import loadingIcon from '../templates/loadingIcon';

class StoredFilter {
  constructor(element) {
    this.element = element;
    this.loadMoreButton = this.element.querySelector('.stored-searches-load-more-button');
    this.loadAllButton = this.element.querySelector('.stored-searches-load-all-button');
    this.fullTextForm = this.element.querySelector('.fulltext-search-form');
    this.fullTextSearchField = this.element.querySelector('.fulltext-search-form .fulltext-search-field');
    this.fullTextFields = this.element.querySelectorAll('.fulltext-search-form button, .fulltext-search-form input');
    this.list = this.element.querySelector('ul.content-list');
    this.count = this.element.querySelector('.pages-count');
    this.search = (this.fullTextSearchField && this.fullTextSearchField.value) || '';

    this.setup();
  }
  setup() {
    if (this.loadMoreButton) this.loadMoreButton.addEventListener('click', this.loadMore.bind(this));
    if (this.loadAllButton) this.loadAllButton.addEventListener('click', this.loadMore.bind(this));
    if (this.fullTextForm) {
      this.fullTextForm.addEventListener('submit', this.filterSearches.bind(this));
      this.fullTextForm.addEventListener('reset', this.resetSearches.bind(this));
    }

    DataCycle.htmlObserver.addCallbacks.push([
      e => e.classList.contains('stored-searches-load-more-button'),
      e => e.addEventListener('click', this.loadMore.bind(this))
    ]);

    DataCycle.htmlObserver.addCallbacks.push([
      e => e.classList.contains('stored-searches-load-all-button'),
      e => e.addEventListener('click', this.loadMore.bind(this))
    ]);

    window.addEventListener('popstate', this.reloadState.bind(this));
  }
  disableForm(triggerField = null) {
    for (const field of this.fullTextFields) DataCycle.disableElement(field);

    if (triggerField) DataCycle.disableElement(triggerField);
    for (const field of Array.from(this.list.querySelectorAll('li.load-more-link a')).filter(v => v != triggerField))
      DataCycle.disableElement(field, field.innerHTML);
  }
  enableForm() {
    for (const field of this.fullTextFields) DataCycle.enableElement(field);

    for (const field of Array.from(this.list.querySelectorAll('li.load-more-link a'))) DataCycle.enableElement(field);
  }
  loadMore(event) {
    event.preventDefault();
    event.stopPropagation();

    const target = event.currentTarget;

    if (target.classList.contains('disabled')) return;

    const lastDayChild = Array.from(this.list.querySelectorAll('.stored-search-day')).pop();

    if (!target.href) return;

    this.list.classList.remove('dc-fd-initialized');
    this.disableForm(target);

    DataCycle.httpRequest({
      url: target.href,
      data: {
        last_day: lastDayChild && lastDayChild.dataset.day,
        q: this.search
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        target.closest('li.load-more-link').remove();
        this.list.insertAdjacentHTML('beforeend', data.html);

        $(this.list).trigger('dc:html:changed').trigger('dc:html:initialized');
      })
      .finally(_error => {
        this.enableForm();
      });
  }
  pushStateToHistory() {
    const url = new URL(window.location);
    if (this.search) url.searchParams.set('q', this.search);
    else url.searchParams.delete('q');
    history.pushState({ search: this.search }, '', url);
  }
  reloadState(event) {
    if (history.state && history.state.hasOwnProperty('search')) {
      this.fullTextSearchField.value = history.state.search;
      this.filterSearches(event, false);
    }
  }
  filterSearches(event, history = true) {
    event.preventDefault();
    event.stopPropagation();

    if (!this.fullTextForm.action) return;

    this.disableForm();

    this.list.innerHTML = loadingIcon();
    this.list.classList.remove('dc-fd-initialized');
    this.count.querySelector('b').innerHTML = loadingIcon();
    this.search = this.fullTextSearchField.value;
    if (history) this.pushStateToHistory();

    DataCycle.httpRequest({
      url: this.fullTextForm.action,
      data: {
        q: this.search
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        if (data.hasOwnProperty('count'))
          I18n.translate('data_cycle_core.stored_searches.count_html', {
            count: data.count,
            count_string: data.count_string
          }).then(html => (this.count.innerHTML = html));

        this.list.innerHTML = data.html;
        $(this.list).trigger('dc:html:changed').trigger('dc:html:initialized');
      })
      .finally(() => {
        this.enableForm();
      });
  }
  resetSearches(event) {
    event.preventDefault();
    event.stopPropagation();

    this.fullTextSearchField.value = '';
    this.filterSearches(event);
  }
}

export default StoredFilter;
