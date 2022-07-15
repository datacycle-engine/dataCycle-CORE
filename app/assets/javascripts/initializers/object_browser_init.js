import ObjectBrowser from './../components/object_browser';

export default function () {
  var object_browsers = [];

  for (const element of document.querySelectorAll('.object-browser'))
    object_browsers.push(new ObjectBrowser($(element)));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('object-browser'),
    e => object_browsers.push(new ObjectBrowser($(e)))
  ]);
}
