import AssetSelector from './../components/asset_selector';
import AssetUploader from './../components/asset_uploader';

export default function () {
  var assetSelectors = [];
  var assetUploaders = [];
  function init(_) {
    $('.asset-selector-reveal:not(.initialized)').each((_, element) => {
      assetSelectors.push(new AssetSelector(element));
    });
    $('.asset-upload-reveal:not(.initialized)').each((_, element) => {
      assetUploaders.push(new AssetUploader(element));
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
    event.stopPropagation();
    init(event.target);
  });
  $(document).on('dc:html:remove', '*', event => {
    event.preventDefault();
    event.stopPropagation();
    if ($(event.target).hasClass('asset-selector-reveal')) {
      assetSelectors = assetSelectors.filter(value => {
        return value.reveal.id != $(event.target).id;
      });
    } else if ($(event.target).hasClass('asset-upload-reveal')) {
      assetUploaders = assetUploaders.filter(value => {
        return value.reveal.id != $(event.target).id;
      });
    }
  });
}
