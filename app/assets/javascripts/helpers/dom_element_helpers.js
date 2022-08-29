import ConfirmationModal from '../components/confirmation_modal';

const DomElementHelpers = {
  isVisible(elem) {
    return elem.offsetWidth > 0 || elem.offsetHeight > 0 || elem.getClientRects().length > 0;
  },
  isHidden(elem) {
    return !this.isVisible(elem);
  },
  findAncestors(elem, filter, ancestors = []) {
    if (!elem) return ancestors;

    if (filter.call(this, elem)) ancestors.push(elem);

    return this.findAncestors(elem.parentElement, filter, ancestors);
  },
  parseDataAttribute(value) {
    if (!value) return value;

    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  },
  elementDepth(elem) {
    let depth = 0;

    while (elem) {
      depth++;
      elem = elem.parentNode;
    }

    return depth;
  },
  randomId(prefix = '') {
    return `${prefix}_${Math.random().toString(36).slice(2)}`;
  },
  renderImportConfirmationModal: async function (field, sourceId, confirmationCallback) {
    const container = field.closest('.form-element');
    const label = container.getElementsByClassName('attribute-label-text')[0];
    const labelText = label && label.innerText;
    const fieldId = sourceId || this.randomId('focus-field');
    container.dataset.focusId = fieldId;

    const text = `${await I18n.translate('frontend.override_warning', {
      data: labelText
    })}<br><br><span class="focus-specific-field" data-field-id="${fieldId}">${await I18n.translate(
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
  },
  getFormData(container) {
    if (container.nodeName === 'FORM') return new FormData(container);

    const formData = new FormData();

    for (const element of $(container).find(':input').serializeArray()) formData.append(element.name, element.value);

    return formData;
  }
};

Object.freeze(DomElementHelpers);

export default DomElementHelpers;
