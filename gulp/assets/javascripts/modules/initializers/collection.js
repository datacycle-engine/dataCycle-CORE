const CollectionFilter = require('../components/collection_filter');

module.exports.initialize = function ($) {
  let collectionLists = [];

  function init(container = document) {
    $(container)
      .find('.dropdown-pane.watch-lists')
      .each((i, elem) => {
        collectionLists.push(new CollectionFilter(elem));
      });
  }

  init();
};
