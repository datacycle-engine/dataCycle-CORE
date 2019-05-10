// var masonry = require('masonry-layout');
var MasonryGrid = require('./../components/masonry_grid');

// Masonry Config
module.exports.initialize = function() {
  init();

  function init(element = document) {
    let gridElem = $(element).hasClass('grid') ? $(element) : $(element).find('.grid');
    if (gridElem.length) {
      gridElem.each((_, item) => {
        new MasonryGrid(item);
      });
    }
  }
};
