class AttributeLocaleSwitcher {
  constructor(localeSwitch) {
    localeSwitch.dcAttributeLocaleSwitcher = true;
    this.$localeSwitch = $(localeSwitch);
    this.$container = this.$localeSwitch.closest('.reveal, #edit-form, .inner-container, .split-content').first();
    this.$form = this.$container.find('form.validation-form').first();
    this.$localeFormField = this.$form.find(':input[name="locale"]');
    this.locale = this.$localeFormField.val() || 'de';
    this.localeUrlParameter = this.$localeSwitch.data('locale-url-parameter') || 'locale';

    this.init();
  }
  init() {
    this.$localeSwitch.on('click', '.available-attribute-locale', this.changeTranslation.bind(this));
    this.$localeFormField.on('change', this.updateLocale.bind(this));
    this.$form.on('dc:form:validationError', this.updateLocaleWithError.bind(this));
    this.$form.on('dc:form:removeValidationError', this.removeLocaleError.bind(this));
    $(window).on('popstate', this.reloadState.bind(this));
  }
  reloadState(_event) {
    if (history.state && history.state.locale)
      this.$localeSwitch
        .find(`.available-attribute-locale[data-locale="${history.state.locale}"]`)
        .trigger('click', { preventHistory: true });
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
  pushStateToHistory() {
    const url = new URL(window.location);
    url.searchParams.set(this.localeUrlParameter, this.locale);
    history.pushState({ locale: this.locale }, '', url);
  }
  changeTranslation(event, data = null) {
    event.preventDefault();
    event.stopPropagation();

    const $target = $(event.currentTarget);

    this.locale = $target.data('locale');
    $target.closest('.attribute-locale-switcher').find('.active').removeClass('active');
    $target.parent('li').addClass('active');

    if (this.$container.find('.split-content').length)
      this.changeTranslationRecursive(this.$container.find('.split-content.edit-content'));
    else this.changeTranslationRecursive(this.$container);

    this.updateLocaleRecursive();

    if (!data || !data.preventHistory) this.pushStateToHistory();
  }
  changeTranslationRecursive($container) {
    $container.find('.template-locale').text(`(${this.locale})`);

    $container
      .find(`.translatable-attribute.${this.locale}, .translatable-field.${this.locale}`)
      .each((_index, item) => {
        if ($(item).siblings('.active').length) {
          $(item).siblings('.active').removeClass('active');
          $(item).addClass('active').trigger('dc:remote:render');
          if ($(item).find('.is-embedded-title').length)
            $(item).find('.is-embedded-title').trigger('dc:embedded:changeTitle');
        }
      });

    $container
      .find('.edit-content-link, a.show-link, a.edit-link, a.load-more-linked-contents, a.load-as-split-source-link')
      .each((_index, item) => {
        if (item.nodeName == 'BUTTON') {
          const $inputField = $(item).siblings('[name="locale"]');

          if ($inputField.length) $inputField.val(this.locale);
          else $(item).after(`<input type="hidden" name="locale" value="${this.locale}">`);
        } else {
          const url = new URL(item.href);
          url.searchParams.set('locale', this.locale);
          item.href = url;
        }
      });

    $container.find('[data-open], [data-toggle]').each((_index, item) => {
      this.changeTranslationRecursive($(`#${$(item).data('open') || $(item).data('toggle')}`));
    });
  }
  updateLocale(event) {
    this.$localeSwitch
      .find(`.available-attribute-locale[data-locale="${$(event.target).val()}"]`)
      .trigger('click', { preventHistory: true });
  }
  updateLocaleRecursive(container = this.$form) {
    $(container)
      .find('.object-browser')
      .each((_i, elem) => {
        if ($(elem).data('locale') != this.locale) $(elem).data('locale', this.locale).trigger('dc:locale:changed');
      });
    $(container)
      .find('.remote-render:not(.translatable-attribute):not(.translatable-field)')
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
      .find('[data-open], [data-toggle]')
      .each((_index, item) => {
        this.updateLocaleRecursive($(`#${$(item).data('open') || $(item).data('toggle')}`));
      });
    $(container).find('.form-element > .embedded-object').data('locale', this.locale);
  }
}

export default AttributeLocaleSwitcher;
