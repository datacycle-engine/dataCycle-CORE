var Validator = require('./../components/validator');
var DataCycleNormalizer = require('./../components/normalizer');

// Add Validation to Form Elements
module.exports.initialize = function() {
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
