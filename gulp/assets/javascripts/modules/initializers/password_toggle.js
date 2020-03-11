module.exports.initialize = function() {
  init();

  function init() {
    $('.password-visibility-toggle').click(event => {
      event.preventDefault();

      $(event.currentTarget)
        .find('.svg-inline--fa')
        .toggleClass('hide');

      let input = $(event.currentTarget).siblings('div.input').children('input');
      if (input.attr('type') == 'password') {
        input.attr('type', 'text');
      } else {
        input.attr('type', 'password');
      }
    });
  }
};
