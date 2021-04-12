const ConditionalField = require('../components/conditional_field');

module.exports.initialize = function ($) {
  let conditionalFields = [];

  initConditionalField();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    initConditionalField(event.currentTarget);
  });

  function initConditionalField(element = document) {
    $(element)
      .find('.conditional-form-field')
      .each((_, elem) => {
        conditionalFields.push(new ConditionalField(elem));
      });
  }
};
