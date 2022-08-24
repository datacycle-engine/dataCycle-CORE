import Validator from './../components/validator';
import BulkUpdateValidator from './../components/bulk_update_validator';
import DataCycleNormalizer from './../components/normalizer';

function initValidator(elem) {
  elem.dcValidator = true;
  if (elem.classList.contains('bulk-edit-form') && window.actionCable) new BulkUpdateValidator(elem);
  else new Validator(elem);
}

export default function () {
  for (const element of document.querySelectorAll('.validation-form')) initValidator(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('validation-form') && !e.hasOwnProperty('dcValidator'),
    e => initValidator(e)
  ]);

  if ($('.normalize-content-button').length) {
    new DataCycleNormalizer($('.normalize-content-button'), $('.edit-content-form'));
  }
}
