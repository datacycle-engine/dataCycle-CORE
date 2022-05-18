import CollectionFilter from '../components/collection_filter';
import CollectionForm from '../components/collection_form';

export default function () {
  let collectionLists = [];

  function init(container = document) {
    $(container)
      .find('.dropdown-pane.watch-lists')
      .each((i, elem) => {
        collectionLists.push(new CollectionFilter(elem));
      });

    for (const collectionForm of document.getElementsByClassName('add-items-to-watch-list-form')) {
      new CollectionForm(collectionForm);
    }
  }

  init();
}
