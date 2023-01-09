import EmbeddedObject from './../components/embedded_object';
import AccordionExtension from './../components/accordion_extension';
import EmbeddedTitle from '../components/embedded_title';

export default function () {
  var embedded_objects = [];
  new AccordionExtension();

  for (const element of document.querySelectorAll('.edit-content-form .embedded-object'))
    embedded_objects.push(new EmbeddedObject($(element)));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('embedded-object') && !e.classList.contains('dcjs-embedded-object'),
    e => embedded_objects.push(new EmbeddedObject($(e)))
  ]);

  for (const element of document.querySelectorAll('.is-embedded-title')) new EmbeddedTitle(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('is-embedded-title') && !e.classList.contains('dcjs-embedded-title'),
    e => new EmbeddedTitle(e)
  ]);
}
