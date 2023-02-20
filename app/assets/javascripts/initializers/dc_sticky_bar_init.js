import DcStickyBar from '../components/dc_sticky_bar';

export default function () {
  DataCycle.initNewElements(
    `${DcStickyBar.stickyHtmlClasses.map(c => `.${c}:not(.dcjs-sticky-bar)`).join(', ')}`,
    e => new DcStickyBar(e)
  );
}
