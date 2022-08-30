const stickyHtmlClasses = ['dc-sticky-bar', 'ql-toolbar'];

function findStickyAncestors(elem, filter, ancestors = []) {
  if (!elem) return ancestors;

  const { overflow } = window.getComputedStyle(elem);
  if (overflow.split(' ').every(o => o === 'auto' || o === 'scroll')) return ancestors;

  let activeElem = elem;
  while (activeElem.previousElementSibling) {
    activeElem = activeElem.previousElementSibling;

    if (stickyHtmlClasses.some(c => activeElem.classList.contains(c))) ancestors.push(activeElem);
  }

  if (stickyHtmlClasses.some(c => elem.classList.contains(c))) ancestors.push(elem);

  return findStickyAncestors(elem.parentElement, filter, ancestors);
}

function calculateStickyOffset(elem) {
  let topOffset = 0;
  const ancestors = findStickyAncestors(elem.parentElement);
  for (const element of ancestors) {
    if (parseInt(window.getComputedStyle(element).zIndex) <= parseInt(window.getComputedStyle(elem).zIndex))
      element.style.zIndex = parseInt(window.getComputedStyle(elem).zIndex) + 1;

    topOffset += element.getBoundingClientRect().height;
  }

  elem.style.setProperty('--dc-sticky-bar-offset', `${topOffset}px`);
}

export default function () {
  for (const elem of document.querySelectorAll(stickyHtmlClasses.map(c => `.${c}`).join(', ')))
    calculateStickyOffset(elem);

  DataCycle.htmlObserver.addCallbacks.push([
    e => !e.hasOwnProperty('dcStickyBar') && stickyHtmlClasses.some(c => e.classList.contains(c)),
    e => calculateStickyOffset(e)
  ]);
}
