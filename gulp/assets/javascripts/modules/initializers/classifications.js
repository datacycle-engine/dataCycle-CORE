module.exports.initialize = function () {
  $('#classification-administration').on('ajax:beforeSend', function(event) {
    var childrenContainer = $(event.target).closest('li').children('ul:not(.classifications)');

    if (childrenContainer.children().length > 0) {
      childrenContainer.toggle();

      return false;
    }
  });

  $('#classification-administration').on('click', 'a.create, a.edit', function(event) {
    $('#classification-administration li.active').removeClass('active');

    $(event.target).closest('li').addClass('active');

    return false;
  });
}
