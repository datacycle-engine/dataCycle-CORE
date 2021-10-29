import EmbeddedObject from './../components/embedded_object';
import AccordionExtension from './../components/accordion_extension';
import EmbeddedTitle from '../components/embedded_title';

export default function () {
  var embedded_objects = [];
  new AccordionExtension();
  new EmbeddedTitle();

  $('.edit-content-form .embedded-object').each((_index, element) => {
    embedded_objects.push(new EmbeddedObject($(element)));
  });

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.embedded-object')
      .each((i, elem) => {
        embedded_objects.push(new EmbeddedObject($(elem)));
      });
  });

  $('.is-embedded-title').each((_index, element) => {
    new EmbeddedTitle(element);
  });

  DataCycle.htmlObserver.addCallbacks.push([e => e.classList.contains('is-embedded-title'), e => new EmbeddedTitle(e)]);
}
