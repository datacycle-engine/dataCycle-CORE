import AttributeLocaleSwitcher from '../components/attribute_locale_switcher';

export default function () {
  for (const element of document.querySelectorAll('.attribute-locale-switcher')) new AttributeLocaleSwitcher(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('attribute-locale-switcher'),
    e => new AttributeLocaleSwitcher(e)
  ]);
}
