import CalloutHelpers from '../helpers/callout_helpers';

class InlineTranslator {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-inline-translator');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.translateText.bind(this));
  }
  getValue() {
    return this.item.closest('.form-element').querySelector(`[name="${this.item.dataset.key}"]`).value;
  }
  getLabel() {
    return this.item.closest('.form-element').dataset.label;
  }
  async setValue(value, sourceLocale) {
    this.item.closest('.form-element').querySelector(`[name="${this.item.dataset.key}"]`).value = value;

    CalloutHelpers.show(
      await I18n.translate('feature.translate.inline_success', {
        source_locale:
          sourceLocale &&
          (await I18n.translate(`locales.${sourceLocale.toLowerCase()}`, {}, sourceLocale.toLowerCase())),
        target_locale: await I18n.translate(`locales.${this.item.dataset.locale}`, {}, this.item.dataset.locale)
      }),
      'success'
    );
  }
  async translateText(event) {
    event.preventDefault();

    DataCycle.disableElement(this.item, '<i class="fa fa-spinner fa-spin fa-fw"></i>');

    const value = this.getValue();

    const { text, detected_source_language: detectedSourceLocale } = await DataCycle.httpRequest({
      url: '/things/translate_text',
      method: 'POST',
      data: {
        text: typeof value == 'string' ? value.trim() : value,
        target_locale: this.item.dataset.locale
      },
      dataType: 'json',
      contentType: 'application/x-www-form-urlencoded'
    }).catch(async error => {
      let errorMessage = await I18n.translate('frontend.split_view.translate_error', {
        label: this.getLabel()
      });
      if (error && error.responseJSON && error.responseJSON.error)
        errorMessage += `<br><i>${error.responseJSON.error}</i>`;
      CalloutHelpers.show(errorMessage, 'alert');
    });

    this.setValue(text, detectedSourceLocale);

    DataCycle.enableElement(this.item);
  }
}

export default InlineTranslator;
