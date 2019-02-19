var Validator = require('./../components/validator');

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

  $(document).on('changed.dc.html', '*', event => {
    init(event.currentTarget);
  });
};
