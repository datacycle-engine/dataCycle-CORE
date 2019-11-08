var ConfirmationModal = require('./../components/confirmation_modal');
var OpenLayerMap = require('./../components/open_layer_map');
var TourSprungEditor = require('./../components/tour_sprung_editor');

// Map Configuration
module.exports.initialize = function() {
  if ($('.object-browser-overlay .item-info-scrollable').length) {
    $('.object-browser-overlay .item-info-scrollable').on('details-changed', event => {
      $(event.target)
        .find('.geographic-map')
        .each((index, item) => {
          initMap(item);
        });
    });
  }

  if ($('.geographic-map').length) {
    $('.geographic-map').each((index, item) => {
      initMap(item);
    });
  }

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.geographic-map')
      .each((index, item) => {
        initMap(item);
      });
  });
};

function initMap(item) {
  let editor = $(item).data('editor');
  let newMap;
  if (editor == 'TourSprung') newMap = new TourSprungEditor(item);
  else newMap = new OpenLayerMap(item);
}
