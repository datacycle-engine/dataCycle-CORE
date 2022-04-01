import AttributeLocaleSwitcher from '../components/attribute_locale_switcher';

export default function () {
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.target);
  });

  init();

  function init(container = document) {
    $(container)
      .find('.attribute-locale-switcher')
      .each((_index, element) => {
        new AttributeLocaleSwitcher(element);
      });
  }
}
