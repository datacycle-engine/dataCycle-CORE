import DashboardPagination from './dashboard_pagination';
import DomElementHelper from '../helpers/dom_element_helpers';

class DashboardTreeLoader extends DashboardPagination {
  constructor(element) {
    super(element);

    this.paginationElement.classList.add('dcjs-dashboard-tree-loader');
    this.paginationContainer = this.paginationElement.closest('.tree-link-container');
    this.locationArray = location.hash.substr(1).split('+').filter(Boolean);
    this.innerItem = this.paginationElement.closest('.inner-item');

    this.openByLocationHash();
  }
  openByLocationHash() {
    if (this.locationArray.length && this.locationArray.includes(this.paginationContainer.id))
      window.requestAnimationFrame(() => this.paginationElement.click());
  }
  loadPage(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.paginationElement.classList.contains('loaded')) return this.innerItem.classList.toggle('open');
    if (!this.form || !this.url) return;

    DataCycle.disableElement(this.paginationElement);
    this.paginationElement.classList.add('loading');

    const formData = new FormData();
    for (const [key, value] of DomElementHelper.parseDataAttribute(this.form.dataset.initialFormData) || [])
      formData.append(key, value);

    this.loadPageContent(formData);
  }
  insertNewData(_page, data) {
    DataCycle.enableElement(this.paginationElement);
    this.paginationElement.classList.remove('loading');
    this.paginationElement.classList.add('loaded');
    this.innerItem.classList.toggle('open');

    this.paginationContainer.insertAdjacentHTML('beforeend', data.html);
  }
}

export default DashboardTreeLoader;
