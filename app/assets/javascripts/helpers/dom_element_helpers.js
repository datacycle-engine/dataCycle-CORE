import ConfirmationModal from '../components/confirmation_modal';
import DcStickyBar from '../components/dc_sticky_bar';

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
  getFormData(container, filterByPrefix = '', removeEmbeddedPrefix = false) {
    let formData = new FormData();
    if (container.nodeName === 'FORM') formData = new FormData(container);
    else
      for (const element of $(container).find(':input').serializeArray()) formData.append(element.name, element.value);

    if (removeEmbeddedPrefix) formData = this.removeEmbeddedPrefixFromFormdata(formData);
    if (filterByPrefix) this.rejectFormdataByPrefix(formData, filterByPrefix);

    return formData;
  },
  removeEmbeddedPrefixFromFormdata(formData) {
    if (!formData) return;

    const newFormData = new FormData();

    for (const [key, value] of Array.from(formData))
      newFormData.append(key.replace(/(datahash|translations)+.+(datahash|translations)+/, `$2`), value);

    return newFormData;
  },
  rejectFormdataByPrefix(formData, prefix) {
    if (!formData) return;

    for (const [key, _value] of Array.from(formData)) if (!key.startsWith(prefix)) formData.delete(key);
  },
  scrollIntoViewWithStickyOffset(element) {
    const { scrollableParent, offset, scrollElement } = this.calculateStickyOffset(element);

    scrollableParent.scrollTo({
      behavior: 'smooth',
      top: element.getBoundingClientRect().top - (offset + 10) - scrollElement.getBoundingClientRect().top
    });
  },
  isScrollable(elem) {
    if (!elem || !elem instanceof Element) return false;

    return window
      .getComputedStyle(elem)
      .overflow.split(' ')
      .every(o => o === 'auto' || o === 'scroll');
  },
  calculateStickyOffset(elem, previousElement = undefined, offset = 0) {
    if (!elem || !elem instanceof Element)
      return { scrollableParent: window, offset: offset, scrollElement: document.body };
    if (this.isScrollable(elem)) return { scrollableParent: elem, offset: offset, scrollElement: previousElement };

    let activeElem = elem;
    while (activeElem.previousElementSibling) {
      activeElem = activeElem.previousElementSibling;

      if (DcStickyBar.stickyHtmlClasses.some(c => activeElem.classList.contains(c)))
        offset += activeElem.getBoundingClientRect().height;
    }

    if (DcStickyBar.stickyHtmlClasses.some(c => elem.classList.contains(c)))
      offset += elem.getBoundingClientRect().height;

    return this.calculateStickyOffset(elem.parentElement, elem, offset);
  }
};

Object.freeze(DomElementHelpers);

export default DomElementHelpers;
