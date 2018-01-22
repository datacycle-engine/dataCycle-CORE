var EmbeddedObject = require('./../components/embedded_object');

// Word Counter
module.exports.initialize = function () {

  var embedded_objects = [];

  $('.edit-content-form .embedded-object').each(function () {
    embedded_objects.push(new EmbeddedObject($(this)));
  });

  $(document).on('clone-added', '.content-object-item', function (event) {
    event.preventDefault();
    event.stopPropagation();
    $(this).find('.embedded-object').each(function () {
      embedded_objects.push(new EmbeddedObject($(this)));
    });
  });
};
