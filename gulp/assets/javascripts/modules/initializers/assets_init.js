// var Asset = require('./../components/asset');
var duration_helpers = require('./../helpers/duration_helpers');
var object_helpers = require('./../helpers/object_helpers');
var AssetSelector = require('./../components/asset_selector');
var AssetUploader = require('./../components/asset_uploader');

// Word Counter
module.exports.initialize = function() {
  // Asset Selector

  var asset_selectors = [];

  function init(container = document) {
    $(container)
      .find('.asset-selector-button')
      .each((index, element) => {
        if ($(element).hasClass('data-link-asset')) {
          new AssetSelector(element, asset_selectors);
        } else {
          asset_selectors.push(new AssetSelector(element, asset_selectors));
        }
      });
  }

  init();

  $(document).on('clone-added', '.content-object-item', event => {
    event.preventDefault();
    event.stopPropagation();
    init(event.target);
  });

  $(document).on('clone-removed', '.content-object-item', event => {
    event.preventDefault();
    event.stopPropagation();
    if ($(event.target).find('.asset-selector-button').length) {
      asset_selectors = asset_selectors.filter(value => {
        return (
          value.button.data('open') !=
          $(event.target)
            .find('.asset-selector-button')
            .first()
            .data('open')
        );
      });

      asset_selectors.forEach(selector => {
        selector.asset_selectors = asset_selectors;
      });
    }
  });

  if ($('#content-upload-reveal').length) {
    var uploader = new AssetUploader($('#content-upload-reveal'));
  }

  $('#content-upload-reveal, .asset-selector-reveal').on('open.zf.reveal', event => {
    $(event.target).appendTo('body');
  });
};
