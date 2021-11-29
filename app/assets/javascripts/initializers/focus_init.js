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
    const values = Array.from(ev.target.parentElement.querySelectorAll(':scope input.dc-multi-value-button'));
    const newIndex = (values.findIndex(e => e.checked) || 0) + 1;
    const selectedOption = values[newIndex >= values.length ? 0 : newIndex];

    if (!selectedOption.disabled && !selectedOption.getAttribute('readonly')) selectedOption.checked = true;
  });
}
