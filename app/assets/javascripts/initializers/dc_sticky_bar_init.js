import DcStickyBar from '../components/dc_sticky_bar';

export default function () {
  for (const elem of document.querySelectorAll(DcStickyBar.joinedStickyHtmlClasses())) new DcStickyBar(elem);

  DataCycle.htmlObserver.addCallbacks.push([
    e => !e.hasOwnProperty('dcStickyBar') && DcStickyBar.stickyHtmlClasses.some(c => e.classList.contains(c)),
    e => new DcStickyBar(e)
  ]);
}
