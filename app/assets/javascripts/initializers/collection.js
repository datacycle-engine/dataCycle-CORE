import CollectionFilter from '../components/collection_filter';
import CollectionForm from '../components/collection_form';
import CollectionOrderButton from '../components/collection_order_button';

export default function () {
  let collectionLists = [];

  function init() {
    for (const elem of document.querySelectorAll('.dropdown-pane.watch-lists')) {
      collectionLists.push(new CollectionFilter(elem));
    }

    for (const collectionForm of document.getElementsByClassName('add-items-to-watch-list-form')) {
      new CollectionForm(collectionForm);
    }

    for (const button of document.getElementsByClassName('manual-order-button')) new CollectionOrderButton(button);
    DataCycle.htmlObserver.addCallbacks.push([
      e => e.classList.contains('manual-order-button') && !e.classList.contains('dcjs-collection-order-button'),
      e => new CollectionOrderButton(e)
    ]);
  }

  init();
}
