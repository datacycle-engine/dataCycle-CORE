import DomElementHelpers from '../helpers/dom_element_helpers';

class DcStickyBar {
  constructor(element) {
    this.element = element;

    this.setup();
  }
  static stickyHtmlClasses = ['dc-sticky-bar', 'ql-toolbar'];
  static joinedStickyHtmlClasses() {
    return this.stickyHtmlClasses.map(c => `.${c}`).join(', ');
  }
  setup() {
    this.element.classList.add('dcjs-sticky-bar');

    this.calculateStickyOffset();
    this.updateAllZIndizes();
  }
  calculateStickyOffset() {
    const { offset } = DomElementHelpers.calculateStickyOffset(this.element.parentElement);

    this.element.style.setProperty('--dc-sticky-bar-offset', `${offset}px`);
  }
  updateAllZIndizes() {
    const allElements = Array.from(document.querySelectorAll(this.constructor.joinedStickyHtmlClasses())).reverse();
    let index = parseInt(window.getComputedStyle(allElements[0]).zIndex);

    for (const elem of allElements) {
      elem.style.zIndex = index;
      ++index;
    }
  }
}

export default DcStickyBar;
