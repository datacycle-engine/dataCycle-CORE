var Validator = require('./../components/validator');
var BulkUpdateValidator = require('./../components/bulk_update_validator');
var DataCycleNormalizer = require('./../components/normalizer');

// Add Validation to Form Elements
module.exports.initialize = function ($) {
  let validation_forms = [];

  function init(container = document) {
    $(container)
      .find('.validation-form')
      .each((i, elem) => {
        if ($(elem).hasClass('bulk-edit-form') && window.actionCable !== undefined)
          validation_forms.push(new BulkUpdateValidator(elem));
        else validation_forms.push(new Validator(elem));
      });
  }

  init();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.currentTarget);
  });

  // init Normalize Button for
  if ($('.normalize-content-button').length) {
    var normalizer = new DataCycleNormalizer($('.normalize-content-button'), $('.edit-content-form'));
  }
};
