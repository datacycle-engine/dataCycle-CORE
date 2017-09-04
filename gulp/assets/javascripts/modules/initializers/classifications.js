module.exports.initialize = function () {
  $('#classification-administration').on('ajax:beforeSend', function(event) {
    var childrenContainer = $(event.target).closest('li').children('ul:not(.classifications)');

    if (childrenContainer.children().length > 0) {
      childrenContainer.toggle();

      return false;
    }
  });
}
