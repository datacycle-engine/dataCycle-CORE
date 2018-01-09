// Confirmation Helpermethods
module.exports = {
  showConfirmation: function (parent, event, text, abort = true, css_class = '', callback = function () {}) {
    parent.find('.confirmation').remove();
    var html = '<div class="confirmation ' + css_class + '" style="position: absolute; transition: none;"><span>';
    html += text
    html += '</span><div class="buttons">';
    if (abort) html += '<button class="button abort" type="button">Abbrechen</button>';
    html += '<button class="button ok" type="button">Ok</button></div></div>';
    parent.append(html);
    parent.find('.confirmation').css({
      top: event.pageY - parent.offset().top - parent.find('.confirmation').outerHeight() - 20,
      left: event.pageX - parent.offset().left - 50
    });

    parent.find('.confirmation .button.ok').click(function (event) {
      event.preventDefault();
      parent.find('.confirmation').remove();
      callback();
    });

    if (abort) {
      parent.find('.confirmation .button.abort').click(function (event) {
        event.preventDefault();
        parent.find('.confirmation').remove();
      });
    }
  }
};
