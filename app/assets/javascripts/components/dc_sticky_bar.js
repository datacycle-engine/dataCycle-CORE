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
    let topOffset = 0;
    const ancestors = this.findStickyAncestors(this.element.parentElement);

    for (const element of ancestors) topOffset += element.getBoundingClientRect().height;

    this.element.style.setProperty('--dc-sticky-bar-offset', `${topOffset}px`);
  }
  findStickyAncestors(elem, ancestors = []) {
    if (!elem) return ancestors;

    const { overflow } = window.getComputedStyle(elem);
    if (overflow.split(' ').every(o => o === 'auto' || o === 'scroll')) return ancestors;

    let activeElem = elem;
    while (activeElem.previousElementSibling) {
      activeElem = activeElem.previousElementSibling;

      if (this.constructor.stickyHtmlClasses.some(c => activeElem.classList.contains(c))) ancestors.push(activeElem);
    }

    if (this.constructor.stickyHtmlClasses.some(c => elem.classList.contains(c))) ancestors.push(elem);

    return this.findStickyAncestors(elem.parentElement, ancestors);
  }
  updateAllZIndizes() {
    const allElements = Array.from(document.querySelectorAll(this.constructor.joinedStickyHtmlClasses())).reverse();

    for (let i = parseInt(window.getComputedStyle(allElements[0]).zIndex); i < allElements.length; ++i) {
      allElements[i].style.zIndex = i;
    }
  }
}

export default DcStickyBar;
