var Asset = require('./../components/asset');

// Word Counter
module.exports.initialize = function () {

  var assets = [];

  $('.edit-content-form .asset .asset-object').each(function () {
    assets.push(new Asset($(this)));
  });

};
