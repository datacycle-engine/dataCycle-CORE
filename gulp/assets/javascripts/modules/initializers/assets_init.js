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
    $('.asset-upload-reveal')
      .filter((index, element) => {
        return asset_uploaders.map(element => element.reveal.prop('id')).indexOf(element.id) === -1;
      })
      .each((index, element) => {
        asset_uploaders.push(new AssetUploader(element));
      });
  }

  init();

  $(document).on('dc:html:changed', '*', event => {
    init(event.target);
  });

  $(document).on('dc:html:remove', '*', event => {
    event.preventDefault();
    event.stopPropagation();
    if ($(event.target).hasClass('asset-selector-reveal')) {
      asset_selectors = asset_selectors.filter(value => {
        return value.reveal.id != $(event.target).id;
      });

      asset_selectors.forEach(selector => {
        selector.asset_selectors = asset_selectors;
      });
    } else if ($(event.target).hasClass('asset-upload-reveal')) {
      asset_uploaders = asset_uploaders.filter(value => {
        return value.reveal.id != $(event.target).id;
      });
    }
  });
};
