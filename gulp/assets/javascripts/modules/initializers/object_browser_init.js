var ObjectBrowser = require('./../components/object_browser');

// Word Counter
module.exports.initialize = function () {

  var object_browsers = [];

  $('.edit-content-form .object-browser').each(function () {
    object_browsers.push(new ObjectBrowser($(this)));
  });

  $(document).on('clone-added', '.content-object-item', function (event) {
    event.preventDefault();
    event.stopPropagation();
    $(this).find('.object-browser').each(function () {
      object_browsers.push(new ObjectBrowser($(this)));
    });
  });

};
