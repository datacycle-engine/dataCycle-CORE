import AssetSelector from './../components/asset_selector';
import AssetUploader from './../components/asset_uploader';

export default function () {
  var assetSelectors = [];
  var assetUploaders = [];

  for (const element of document.querySelectorAll('.asset-selector-reveal:not(.dc-asset-selector)'))
    assetSelectors.push(new AssetSelector(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('asset-selector-reveal') && !e.classList.contains('dc-asset-selector'),
    e => assetSelectors.push(new AssetSelector(e))
  ]);

  for (const element of document.querySelectorAll('.asset-upload-reveal:not(.dc-asset-uploader)'))
    assetUploaders.push(new AssetUploader(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('asset-upload-reveal') && !e.classList.contains('dc-asset-uploader'),
    e => assetUploaders.push(new AssetUploader(e))
  ]);

  for (const element of document.querySelectorAll('.download-content-form')) initDownloadContentReveal(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('download-content-form'),
    e => initDownloadContentReveal(e)
  ]);

  function initDownloadContentReveal(element) {
    toggleAssetVersion(element);
    toggleAssetTransformation(element);

    $(element)
      .find('.active.serialize_formats input')
      .on('change', event => {
        event.preventDefault();
        toggleAssetVersion(element);
      });

    $(element)
      .find('.active.version input')
      .on('change', event => {
        event.preventDefault();
        toggleAssetTransformation(element);
      });
  }

  function toggleAssetVersion(element) {
    if ($(element).find('.active.serialize_formats :input[value="asset"]').is(':checked')) {
      $(element).find('.active.version').removeClass('hidden');
    } else {
      $(element).find('.active.version').addClass('hidden');
    }

    toggleAssetTransformation(element);
  }

  function toggleAssetTransformation(element) {
    let selectedVal = $(element).find('.active.version :input[name="version"]:checked').val();
    $(element).find('.active.transformation').addClass('hidden');
    if ($(element).find('.active.serialize_formats :input[value="asset"]').is(':checked')) {
      $(element)
        .find('.active.transformation.' + selectedVal)
        .removeClass('hidden');
    }
  }
}
