// Flash Callout Helpermethods
module.exports = {
  show: function (text, type = '') {
    let temp = $('<div data-text="' + text + '" class="flash callout ' + type + '" data-closable="" style="display: none;">' + text + '<button name="button" type="button" class="close-button" data-close="" aria-label="Dismiss alert"><span aria-hidden="true">×</span></button></div>').insertBefore('header').slideDown('fast');
    setTimeout(() => {
      $(temp).slideUp('slow', function () {
        $(this).remove();
      });
    }, 4000);
  }
};
