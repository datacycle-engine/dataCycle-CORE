import StoredFilter from '../components/stored_filter';
import StoredFilterForm from '../components/stored_filter_form';

export default function () {
  const storedSearchesList = document.querySelector('.stored-searches-list');

  if (storedSearchesList) new StoredFilter(storedSearchesList);

  if (document.querySelector('.save-filter-with-params')) {
    DataCycle.htmlObserver.addCallbacks.push([
      e => e.classList.contains('update-stored-search-form') && e.dataset.updateParams == 'true',
      e => new StoredFilterForm(e)
    ]);
  }
}
