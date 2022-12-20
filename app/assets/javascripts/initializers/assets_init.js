import AssetSelector from './../components/asset_selector';
const AssetUploader = () => import('./../components/asset_uploader');

function initAssetUploader(item) {
  item.classList.add('dcjs-asset-uploader');
  AssetUploader().then(mod => new mod.default(item));
}

export default function () {
  for (const element of document.querySelectorAll('.asset-selector-reveal')) new AssetSelector(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('asset-selector-reveal') && !e.classList.contains('dcjs-asset-selector'),
    e => new AssetSelector(e)
  ]);

  for (const element of document.querySelectorAll('.asset-upload-reveal')) initAssetUploader(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('asset-upload-reveal') && !e.classList.contains('dcjs-asset-uploader'),
    e => initAssetUploader(e)
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
