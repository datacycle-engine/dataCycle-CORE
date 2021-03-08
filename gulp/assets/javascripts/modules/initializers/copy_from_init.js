const CopyFromAttribute = require('./../components/copy_from_attribute');

module.exports.initialize = function ($) {
  let copyFromAttributeFeatures = [];

  function init(container = document) {
    $(container)
      .find('.copy-from-attribute-feature')
      .each((_, elem) => {
        copyFromAttributeFeatures.push(new CopyFromAttribute(elem));
      });
  }

  init();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });
};
