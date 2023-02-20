import AttributeLocaleSwitcher from '../components/attribute_locale_switcher';

export default function () {
  DataCycle.initNewElements(
    '.attribute-locale-switcher:not(.dcjs-attribute-locale-switcher)',
    e => new AttributeLocaleSwitcher(e)
  );
}
