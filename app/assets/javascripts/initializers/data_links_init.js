import DataLinkForm from '../components/data_link_form';

export default function () {
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('data-link-form') && !e.hasOwnProperty('dcDataLinkForm'),
    e => new DataLinkForm(e)
  ]);
}
