import Validator from './../components/validator';
import BulkUpdateValidator from './../components/bulk_update_validator';
import DataCycleNormalizer from './../components/normalizer';

export default function () {
  let validation_forms = [];

  function init(container = document) {
    $(container)
      .find('.validation-form')
      .each((_, elem) => {
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

  if ($('.normalize-content-button').length) {
    new DataCycleNormalizer($('.normalize-content-button'), $('.edit-content-form'));
  }
}
