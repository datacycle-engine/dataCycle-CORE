import ConfirmationModal from '../components/confirmation_modal';

export default {
  isVisible: function (elem) {
    return elem.offsetWidth > 0 || elem.offsetHeight > 0 || elem.getClientRects().length > 0;
  },
  parseDataAttribute: function (value) {
    if (!value) return value;

    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  },
  randomId: function (prefix = '') {
    return `${prefix}_${Math.random().toString(36).slice(2)}`;
  },
  renderImportConfirmationModal: async function (field, sourceId, confirmationCallback) {
    const container = field.closest('.form-element');
    const label = container.getElementsByClassName('attribute-label-text')[0];
    const labelText = label && label.innerText;
    const targetId = this.randomId('focus-target');
    container.dataset.focusId = targetId;

    const focusFieldIds = [targetId];
    if (sourceId) focusFieldIds.push(sourceId);

    const text = `${await I18n.translate('frontend.override_warning', {
      data: labelText
    })}<br><br><span class="focus-specific-field" data-field-ids="${focusFieldIds}">${await I18n.translate(
      'frontend.override_focus'
    )}</span>`;

    new ConfirmationModal({
      text: text,
      confirmationText: await I18n.translate('common.yes'),
      cancelText: await I18n.translate('common.no'),
      confirmationClass: 'success',
      cancelable: true,
      confirmationCallback: confirmationCallback
    });
  }
};
