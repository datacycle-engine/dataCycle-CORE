import CollectionFilter from '../components/collection_filter';

export default function () {
  let collectionLists = [];

  function init(container = document) {
    $(container)
      .find('.dropdown-pane.watch-lists')
      .each((i, elem) => {
        collectionLists.push(new CollectionFilter(elem));
      });
  }

  init();
}
