import ObjectBrowser from './../components/object_browser';

export default function () {
  var object_browsers = [];

  $('.object-browser').each((_i, elem) => {
    object_browsers.push(new ObjectBrowser($(elem)));
  });

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    $(event.target)
      .find('.object-browser')
      .each((_i, elem) => {
        object_browsers.push(new ObjectBrowser($(elem)));
      });
  });
}
