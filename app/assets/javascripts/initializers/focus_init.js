export default function () {
  $(document).on('focusout', '.form-element', function (ev) {
    setTimeout(
      function () {
        if ($(this).find(':focus').addBack(':focus').length == 0) {
          $(this).removeClass('focus');
        }
      }.bind(this),
      50
    );
  });

  $(document).on('focusin', '.form-element', function (ev) {
    $(this).addClass('focus');
  });

  // dc multi-value-button

  $(document).on('click', '.dc-multi-value-label:not(:disabled)', ev => {
    ev.preventDefault();

    const values = Array.from(ev.target.parentElement.querySelectorAll('input.dc-multi-value-button'));
    const newIndex = (values.findIndex(e => e.checked) || 0) + 1;

    values[newIndex >= values.length ? 0 : newIndex].checked = true;
  });
}
