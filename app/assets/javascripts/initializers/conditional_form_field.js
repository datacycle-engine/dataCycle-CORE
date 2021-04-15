export default function () {
  $('.conditional-form-field').each((index, elem) => {
    initConditionalField(elem);
  });

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.currentTarget)
      .find('.conditional-form-field')
      .each((_, elem) => {
        initConditionalField(elem);
      });
  });

  function initConditionalField(field) {
    $(field)
      .find('.conditional-field-selector > label > :radio')
      .off('click')
      .on('click', event => {
        $(field).find('.conditional-field-content').removeClass('active').find(':input').prop('disabled', true);

        $(field)
          .find('.conditional-' + $(event.currentTarget).val() + '-content')
          .addClass('active')
          .find(':input')
          .prop('disabled', false);
      });
  }
}
