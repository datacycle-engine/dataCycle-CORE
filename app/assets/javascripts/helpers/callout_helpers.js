import lodashEscape from 'lodash/escape';

export default {
  show: function (text, type = '') {
    if (!$('.flash-messages').length) $('body').prepend('<div class="flash-messages"></div');

    let temp = $(
      `<div data-text="${lodashEscape(
        text
      )}" class="flash flash-notification callout ${type}" data-closable style="display: none;">${text}<button name="button" type="button" class="close-button" data-close aria-label="Dismiss alert"><span aria-hidden="true">×</span></button></div>`
    )
      .appendTo('.flash-messages')
      .slideDown('fast');
    setTimeout(() => {
      $(temp).slideUp('fast', function () {
        $(this).remove();
      });
    }, 4000);
  }
};
