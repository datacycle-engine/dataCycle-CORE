import DashboardPagination from './dashboard_pagination';

class DashboardTreeLoader extends DashboardPagination {
  constructor(element) {
    super(element);

    this.paginationContainer = this.paginationElement.closest('.tree-link-container');
    this.innerItem = this.paginationElement.closest('.inner-item');
  }
  loadPage(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.paginationElement.classList.contains('loaded')) return this.innerItem.classList.toggle('open');
    if (!this.form || !this.url) return;

    DataCycle.disableElement(this.paginationElement);
    this.paginationElement.classList.add('loading');

    const formData = new FormData();
    for (const [key, value] of this.form.dcDashboardFilter.initialFormData) formData.set(key, value);

    this.loadPageContent(formData);
  }
  insertNewData(data) {
    DataCycle.enableElement(this.paginationElement);
    this.paginationElement.classList.remove('loading');
    this.paginationElement.classList.add('loaded');
    this.innerItem.classList.toggle('open');

    this.paginationContainer.insertAdjacentHTML('beforeend', data.html);

    $(this.paginationContainer.querySelector(':scope > .children')).trigger('dc:html:changed');

    $(this.paginationContainer.querySelector(':scope > .contents')).trigger('dc:html:changed');
  }
}

export default DashboardTreeLoader;
