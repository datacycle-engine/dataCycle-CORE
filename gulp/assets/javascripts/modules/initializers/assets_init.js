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

    toggleAssetVersion();
    toggleAssetTransformation();
    $('.download-content-reveal .active.serialize_formats input').on('change', event => {
      event.preventDefault();
      toggleAssetVersion();
    });
    $('.download-content-reveal .active.version input').on('change', event => {
      event.preventDefault();
      toggleAssetTransformation();
    });
  }

  function toggleAssetVersion() {
    if ($('.download-content-reveal .active.serialize_formats #serialize_format_asset').is(':checked')) {
      $('.download-content-reveal .active.version').removeClass('hidden');
    } else {
      $('.download-content-reveal .active.version').addClass('hidden');
    }
    toggleAssetTransformation();
  }

  function toggleAssetTransformation() {
    let selectedVal = $('.download-content-reveal .active.version :input[name="version"]:checked').val();

    $('.download-content-reveal .active.transformation').addClass('hidden');
    if ($('.download-content-reveal .active.serialize_formats #serialize_format_asset').is(':checked')) {
      $('.download-content-reveal .active.transformation.' + selectedVal).removeClass('hidden');
    }
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
