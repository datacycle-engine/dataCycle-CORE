import StoredFilter from '../components/stored_filter';
import StoredFilterForm from '../components/stored_filter_form';
import StoredSearchesFilter from '../components/stored_searches_filter';

export default function () {
  const storedSearchesList = document.querySelector('.stored-searches-list');
  if (storedSearchesList) new StoredFilter(storedSearchesList);

  if (document.querySelector('.save-filter-with-params')) {
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.classList.contains('update-stored-search-form') &&
        e.dataset.updateParams == 'true' &&
        !e.classList.contains('dcjs-stored-filter-form'),
      e => new StoredFilterForm(e)
    ]);
  }

  const storedSearchesFilter = document.getElementById('search-favorites-fulltext-filter');
  if (storedSearchesFilter) new StoredSearchesFilter(storedSearchesFilter);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.id === 'search-favorites-fulltext-filter' && !e.classList.contains('dcjs-stored-searches-filter'),
    e => new StoredSearchesFilter(e)
  ]);
}
