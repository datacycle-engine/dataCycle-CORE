var Validator = require('./../components/validator');
var DataCycleNormalizer = require('./../components/normalizer');

// Add Validation to Form Elements
module.exports.initialize = function() {
  // multi-edit
  $(document).on('change', '.bulk-edit-form .editor > .form-element', event => {
    let updateCheckbox = $(event.currentTarget)
      .siblings('.bulk-update-check[data-attribute-key="' + $(event.currentTarget).data('key') + '"]')
      .find(':checkbox');
    if (
      $(event.currentTarget)
        .find(':input')
        .serializeArray()
        .some(elem => elem.value && elem.value.length)
    )
      updateCheckbox.prop('checked', true);
    else updateCheckbox.prop('checked', false);
  });

  let validation_forms = [];

  function init(container = document) {
    $(container)
      .find('.validation-form')
      .each((i, elem) => {
        validation_forms.push(new Validator(elem));
      });
  }

  init();

  $(document).on('dc:html:changed', '*', event => {
    init(event.currentTarget);
  });

  // init Normalize Button for
  if ($('.normalize-content-button').length) {
    var normalizer = new DataCycleNormalizer($('.normalize-content-button'), $('.edit-content-form'));
  }
};
