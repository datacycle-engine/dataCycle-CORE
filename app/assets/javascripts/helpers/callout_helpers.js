import lodashEscape from 'lodash/escape';

export default {
  show: function (text, type = '') {
    let temp = $(
      `<div data-text="${lodashEscape(
        text
      )}" class="flash flash-notification callout ${type}" data-closable style="display: none;">${text}<button name="button" type="button" class="close-button" data-close aria-label="Dismiss alert"><span aria-hidden="true">×</span></button></div>`
    )
      .insertBefore('header')
      .slideDown('fast');
    setTimeout(() => {
      $(temp).slideUp('fast', function () {
        $(this).remove();
      });
    }, 4000);
  }
};
