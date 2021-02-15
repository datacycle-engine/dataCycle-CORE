module.exports.initialize = function ($) {
  $(document).on('click', 'a.copy-from-attribute-button', copyValueFromAttribute);

  function copyValueFromAttribute(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    const $formElement = $(event.currentTarget).parent('.form-element');
    const targetKey = $(event.currentTarget).data('copyFrom');
    const label = $formElement.data('label');
    const $target = $formElement.siblings('[data-key*="' + targetKey + '"]').first();

    if (!$target.length) return;

    let value = $target.find(':input').serializeArray();

    if (value.length && $target.find(':input').first().prop('name').endsWith('[]')) value = value.map(v => v.value);
    else if (value.length) value = value[0].value;

    if (typeof value == 'string') value = value.trim();

    $formElement.find(window.EDITORSELECTORS.join(', ')).trigger('dc:import:data', {
      label: label,
      value: value,
      locale: $formElement.closest('form').find(':hidden[name="locale"]').val() || ''
    });
  }
};
