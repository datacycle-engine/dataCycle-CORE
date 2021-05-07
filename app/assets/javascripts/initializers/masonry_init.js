import MasonryGrid from './../components/masonry_grid';

export default function () {
  init();

  function init(element = document) {
    let gridElem = $(element).hasClass('grid') ? $(element) : $(element).find('.grid');
    if (gridElem.length) {
      gridElem.each((_, item) => {
        new MasonryGrid(item);
      });
    }
  }
}
