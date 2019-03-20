var ObjectBrowser = require('./../components/object_browser');

// Word Counter
module.exports.initialize = function() {
  var object_browsers = [];

  $('.edit-content-form .object-browser').each((i, elem) => {
    object_browsers.push(new ObjectBrowser($(elem)));
  });

  $(document).on('changed.dc.html', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.object-browser')
      .each((i, elem) => {
        object_browsers.push(new ObjectBrowser($(elem)));
      });
  });
};
