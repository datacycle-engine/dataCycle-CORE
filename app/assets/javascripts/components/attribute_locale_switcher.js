class AttributeLocaleSwitcher {
  constructor(localeSwitch) {
    this.$localeSwitch = $(localeSwitch);
    this.$container = this.$localeSwitch.closest('.reveal, #edit-form');
    this.$form = this.$container.find('form.validation-form').first();
    this.$localeFormField = this.$form.find(':input[name="locale"]');
    this.locale = this.$localeFormField.val() || 'de';
    this.activeLocale = this.locale;

    this.init();
  }
  init() {
    this.$localeSwitch.on('click', '.available-attribute-locale', this.changeTranslation.bind(this));
    this.$localeFormField.on('change', this.updateLocale.bind(this));
    this.$form.on('dc:form:validationError', this.updateLocaleWithError.bind(this));
    this.$form.on('dc:form:removeValidationError', this.removeLocaleError.bind(this));
  }
  updateLocaleWithError(event, data) {
    event.preventDefault();

    if (!data.locale) return;

    this.$localeSwitch
      .find(`.available-attribute-locale[data-locale="${data.locale}"]`)
      .addClass(`validation-${data.type}`);
  }
  removeLocaleError(event, data) {
    event.preventDefault();

    if (data.locale)
      this.$localeSwitch
        .find(`.available-attribute-locale.validation-${data.type}[data-locale="${data.locale}"]`)
        .removeClass(`validation-${data.type}`);
    else
      this.$localeSwitch
        .find(`.available-attribute-locale.validation-${data.type}`)
        .removeClass(`validation-${data.type}`);
  }
  changeTranslation(event) {
    event.preventDefault();

    const $target = $(event.currentTarget);

    this.activeLocale = $target.data('locale');
    $target.closest('.attribute-locale-switcher').find('.active').removeClass('active');
    $target.parent('li').addClass('active');

    this.$form.find('.translatable-attribute.active').removeClass('active');
    this.$form
      .find(`.translatable-attribute.${$target.data('locale')}`)
      .addClass('active')
      .trigger('dc:remote:render');
  }
  updateLocale(event) {
    this.locale = $(event.target).val();
    this.updateLocaleRecursive();
  }
  updateLocaleRecursive(container = this.$form) {
    $(container)
      .find('.object-browser')
      .each((_i, elem) => {
        if ($(elem).data('locale') != this.locale) $(elem).data('locale', this.locale).trigger('dc:locale:changed');
      });
    $(container)
      .find('.remote-render')
      .each((_i, elem) => {
        if ($(elem).data('remote-options').locale !== undefined) $(elem).data('remote-options').locale = this.locale;
      });
    $(container)
      .find('.form-crumbs .locale, form.multi-step fieldset legend .locale')
      .each((_i, elem) => {
        if ($(elem).text() != this.locale) $(elem).text('(' + this.locale + ')');
      });
    $(container)
      .find(':input[name="locale"]')
      .each((_i, elem) => {
        if ($(elem).val() != this.locale) $(elem).val(this.locale);
      });
    $(container)
      .find('form.multi-step')
      .each((_i, elem) => {
        if ($(elem).data('locale') != this.locale) $(elem).data('locale', this.locale);
      });
    $(container)
      .find('.button.show-objectbrowser, .new-content-button')
      .each((_i, elem) => {
        this.updateLocalesRecursive($('#' + ($(elem).data('open') || $(elem).data('toggle'))));
      });
  }
}

export default AttributeLocaleSwitcher;
