// var masonry = require('masonry-layout');

// Masonry Config
module.exports.initialize = function() {
  var el = document.createElement('div');
  var supports_grid = typeof el.style.grid === 'string';
  if (!supports_grid) {
    $('body').append(
      '<div class="html-feature-missing"><h2>Verwenden Sie bitte einen aktuellen Browser um diese Anwendung korrekt darstellen zu können!</h2></div>'
    );
  }

  function init(element = document) {
    if ($(element).find('.grid').length) resizeAllMasonryItems(element);
  }

  function resizeMasonryItem(item) {
    let grid = $(item)
        .closest('.grid')
        .get(0),
      rowGap = parseInt(window.getComputedStyle(grid).getPropertyValue('grid-row-gap')),
      rowHeight = parseInt(window.getComputedStyle(grid).getPropertyValue('grid-auto-rows'));

    let rowSpan = Math.round(
      (item.querySelector('.content-link').getBoundingClientRect().height + rowGap) / (rowHeight + rowGap)
    );

    item.style.gridRowEnd = 'span ' + rowSpan;
  }

  function resizeAllMasonryItems(container = document) {
    let allItems = $(container)
      .find('.grid-item')
      .get();

    $(container)
      .find('.grid-loading')
      .hide();

    $(container)
      .find('.grid-item')
      .show();

    for (let i = 0; i < allItems.length; i++) {
      resizeMasonryItem(allItems[i]);
    }
  }

  $(document).on('lazyloaded', '*', event => {
    if ($(event.target).closest('.grid-item').length)
      resizeMasonryItem(
        $(event.target)
          .closest('.grid-item')
          .get(0)
      );
  });

  let masonryEvents = ['load', 'resize'];

  $(document)
    .find('.grid')
    .on('load', event => {
      console.log('load');
    });

  masonryEvents.forEach(event => {
    window.addEventListener(event, event => {
      if ($(document).find('.grid').length) resizeAllMasonryItems();
    });
  });

  init();
};
