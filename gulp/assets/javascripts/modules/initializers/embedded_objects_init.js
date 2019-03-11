var EmbeddedObject = require('./../components/embedded_object');

// Word Counter
module.exports.initialize = function() {
  var embedded_objects = [];

  $('.edit-content-form .embedded-object').each((index, element) => {
    embedded_objects.push(new EmbeddedObject($(element)));
  });

  $(document).on('changed.dc.html', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.embedded-object')
      .each((i, elem) => {
        embedded_objects.push(new EmbeddedObject($(elem)));
      });
  });
};
