var Asset = require('./../components/asset');

// Word Counter
module.exports.initialize = function () {

  var assets = [];

  $('.edit-content-form .asset').each(function () {
    assets.push(new Asset($(this)));
  });

};
