import EmbeddedObject from '~/javascripts/components/embedded_object';
import AccordionExtension from '~/javascripts/components/accordion_extension';

// Word Counter
export default function () {
  var embedded_objects = [];
  var accorion_extension = new AccordionExtension();

  $('.edit-content-form .embedded-object').each((index, element) => {
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

  $(document).on('change', '.form-element.is-embedded-title', event => {
    let value = $(event.currentTarget).find(':input').first().val();
    let titleField = $(event.currentTarget)
      .closest('.content-object-item')
      .find('> .accordion-title > .title > .embedded-title');

    titleField.text(value);
    titleField.attr('title', value);

    if (value && value.length) titleField.addClass('visible');
    else titleField.removeClass('visible');
  });
}
