// var Asset = require('./../components/asset');
var duration_helpers = require('./../helpers/duration_helpers');
var object_helpers = require('./../helpers/object_helpers');
var AssetSelector = require('./../components/asset_selector');
var AssetUploader = require('./../components/asset_uploader');

// Word Counter
module.exports.initialize = function() {
  // Asset Selector

  var asset_selectors = [];
  var asset_uploaders = [];

  function init_selectors(container = document) {
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

  function init_uploaders(container = document) {
    $('.asset-upload-reveal')
      .filter((index, element) => {
        return asset_uploaders.map(element => element.reveal.prop('id')).indexOf(element.id) === -1;
      })
      .each((index, element) => {
        asset_uploaders.push(new AssetUploader(element));
      });
  }

  init_selectors();
  init_uploaders();

  $(document).on('changed.dc.html', '*', event => {
    init_selectors(event.target);
    init_uploaders(event.target);
  });

  $(document).on('remove.dc.html', '*', event => {
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
};
