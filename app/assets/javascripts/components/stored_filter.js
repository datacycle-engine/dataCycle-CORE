import loadingIcon from '../templates/loadingIcon';

class StoredFilter {
  constructor(element) {
    this.element = element;
    this.loadMoreButton = this.element.querySelector('.stored-searches-load-more-button');
    this.fullTextForm = this.element.querySelector('.fulltext-search-form');
    this.list = this.element.querySelector('ul.content-list');
    this.count = this.element.querySelector('.pages-count');

    this.setup();
  }
  setup() {
    if (this.loadMoreButton) this.loadMoreButton.addEventListener('click', this.loadMore.bind(this));
    if (this.fullTextForm) {
      this.fullTextForm.addEventListener('submit', this.filterSearches.bind(this));
      this.fullTextForm.addEventListener('reset', this.resetSearches.bind(this));
    }

    DataCycle.htmlObserver.addCallbacks.push([
      e => e.classList.contains('stored-searches-load-more-button'),
      e => e.addEventListener('click', this.loadMore.bind(this))
    ]);
  }
  loadMore(event) {
    event.preventDefault();
    event.stopPropagation();

    const target = event.currentTarget;
    const lastDayChild = Array.from(this.list.querySelectorAll('.stored-search-day')).pop();
    const search = this.fullTextForm && this.fullTextForm.querySelector('.fulltext-search-field').value;

    if (!target.href) return;

    DataCycle.disableElement(target);

    DataCycle.httpRequest({
      url: target.href,
      data: {
        last_day: lastDayChild && lastDayChild.dataset.day,
        q: search
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        $(data.html)
          .replaceAll($(target.closest('li.load-more-link')))
          .trigger('dc:html:changed')
          .trigger('dc:html:initialized');
      })
      .catch(_error => {
        DataCycle.enableElement(target);
      });
  }
  filterSearches(event) {
    event.preventDefault();
    event.stopPropagation();

    const target = event.currentTarget;
    const inputs = target.querySelectorAll('.fulltext-search-submit, .fulltext-search-field, .fulltext-search-reset');

    if (!target.action) return;

    for (const input of inputs) DataCycle.disableElement(input);
    this.list.innerHTML = loadingIcon();
    this.count.querySelector('b').innerHTML = loadingIcon();

    DataCycle.httpRequest({
      url: target.action,
      data: {
        q: target.querySelector('.fulltext-search-field').value
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        for (const child of this.list.children) child.remove();
        if (data.hasOwnProperty('count'))
          I18n.translate('data_cycle_core.stored_searches.count_html', {
            count: data.count,
            count_string: data.count_string
          }).then(html => (this.count.innerHTML = html));
        $(data.html).appendTo($(this.list)).trigger('dc:html:changed').trigger('dc:html:initialized');
      })
      .finally(() => {
        for (const input of inputs) DataCycle.enableElement(input);
      });
  }
  resetSearches(event) {
    event.preventDefault();
    event.stopPropagation();

    this.fullTextForm.querySelector('.fulltext-search-field').value = '';
    this.filterSearches(event);
  }
}

export default StoredFilter;
