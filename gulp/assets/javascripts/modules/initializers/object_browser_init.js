var Objectbrowser = require('./../components/object_browser');

// Word Counter
module.exports.initialize = function () {

  var object_browsers = [];

  $('.edit-content-form .object-browser').each(function () {
    object_browsers.push(new Objectbrowser($(this)));
  });

};
