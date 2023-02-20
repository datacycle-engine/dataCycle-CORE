import DataLinkForm from '../components/data_link_form';

export default function () {
  DataCycle.initNewElements('.data-link-form:not(.dcjs-data-link-form)', e => new DataLinkForm(e));
}
