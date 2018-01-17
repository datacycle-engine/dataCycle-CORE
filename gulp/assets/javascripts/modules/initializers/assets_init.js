var Asset = require('./../components/asset');

// Word Counter
module.exports.initialize = function () {

  var assets = [];

  $('.edit-content-form .asset .asset-object').each(function () {
    assets.push(new Asset($(this)));
  });

  $(document).on('clone-added', '.content-object-item', function (event) {
      event.preventDefault();
      event.stopPropagation();
      $(this).find('.asset .asset-object').each(function () {
          assets.push(new Asset($(this)));
      });
  });

};
