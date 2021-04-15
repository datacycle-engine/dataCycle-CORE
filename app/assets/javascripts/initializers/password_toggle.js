export default function () {
  init();

  function init() {
    $(document).on('click', '.password-visibility-toggle', event => {
      event.preventDefault();

      $(event.currentTarget).find('.fa').toggleClass('hide');

      let input = $(event.currentTarget).siblings('div.input').children('input');
      if (input.attr('type') == 'password') {
        input.attr('type', 'text');
      } else {
        input.attr('type', 'password');
      }
    });

    $(document).on('input', '.password-field input', event => {
      event.preventDefault();

      const $visibilityToggle = $(event.currentTarget).closest('.password-field');

      if (event.currentTarget.value) $visibilityToggle.addClass('has-value');
      else $visibilityToggle.removeClass('has-value');
    });
  }
}
