import ObjectBrowser from './../components/object_browser';

export default function () {
  DataCycle.initNewElements('.object-browser:not(.dcjs-object-browser)', e => new ObjectBrowser(e));
}
