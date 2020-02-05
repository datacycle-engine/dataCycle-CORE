let QuillHelpers = require('./../helpers/quill_helpers');

// New Content Dialog
class NewContentDialog {
  constructor(form) {
    this.form = $(form);
    this.nextButton = this.form.find('.next');
    this.prevButton = this.form.find('.prev');
    this.resetButton = this.form.find('.button.reset');
    this.crumbs = this.form.find('.form-crumbs');
    this.contentUploader = this.form.data('content-uploader');
    this.id = this.form.closest('.new-content-form').attr('id');
    this.locale = this.form.find(':input[name="locale"]').val() || 'de';
    this.activeLocale = this.locale;
    this.reveal = this.form.closest('.reveal.new-content-reveal');
    this.referencedAssetField;
    this.nextAssetButton;
    this.prevAssetButton;
    this.init();
    this.initEventHandlers();
    this.updateForm();
  }
  init() {
    if (this.contentUploader) {
      this.setReferencedAssetField();
    }
  }
  initEventHandlers() {
    if (this.form.find('fieldset.active').length == 0)
      this.form
        .find('fieldset')
        .first()
        .addClass('active');
    this.nextButton.on('click', this.next.bind(this));
    this.prevButton.on('click', this.prev.bind(this));
    this.form.on('click', '.form-crumb-link', this.goTo.bind(this));
    this.form.on('reset', this.resetForm.bind(this));
    this.form.on('change', ':input[name="locale"]', this.updateLocales.bind(this));
    this.form.on('dc:multistep:goto', this.goTo.bind(this));
    this.form.on('click', '.translated-attribute-locale', event => {
      event.preventDefault();
      this.changeTranslation(event.target);
    });
    this.form.on('keypress', event => {
      if (event.which == 13 && this.form.find('fieldset.active:not(:last-of-type)').length) {
        event.preventDefault();
        this.next(event);
      }
    });
    this.form.on('dc:asset:selected', '.form-element', this.checkSelectedAsset.bind(this));
    this.form.on('click', '.copy-attribute-to-all', this.copySingleToAllReferenceFields.bind(this));
    this.form.find('.translated-attribute.active').trigger('dc:remote:render');

    if (this.referencedAssetField) {
      this.updateNavigationButtons();
      this.addCopyAttributeButtons(this.form);
      this.reveal.on('open.zf.reveal', event => {
        this.form.trigger('dc:form:enable');
        this.updateNavigationButtons(event);
      });
      this.referencedAssetField.on('dc:form:importAttributeValues', this.importAttributeValues.bind(this));
      this.form.on('dc:form:submitWithoutRedirect', this.copyToReferenceField.bind(this));
      this.form.find('.set-all-attributes').on('click', this.copyToAllReferenceFields.bind(this));
      this.form.on('dc:html:initialized', '.translated-attribute', event => {
        event.stopPropagation();
        this.addCopyAttributeButtons(event.currentTarget);
        this.triggerSyncWithContentUploader(event);
      });
      this.triggerSyncWithContentUploader();
    }
  }
  copyToReferenceField(event, config = {}) {
    event.preventDefault();

    QuillHelpers.updateEditors(this.form);
    let formData = this.form.serializeArray();

    if (config && config.allFiles) this.reveal.foundation('close');
    else this.nextAssetForm(event);

    this.referencedAssetField.trigger('dc:upload:setFormFields', {
      formData: formData,
      allFiles: config && config.allFiles
    });
  }
  copyToAllReferenceFields(event) {
    this.form.trigger('submit', { allFiles: true });
  }
  copySingleToAllReferenceFields(event) {
    let buttonHtml = $(event.currentTarget).html();
    $(event.currentTarget)
      .html('<i class="fa fa-circle-o-notch fa-spin"></i>')
      .addClass('disabled');
    event.preventDefault();
    event.stopImmediatePropagation();

    QuillHelpers.updateEditors(this.form);
    let formData = this.form.serializeArray();
    let formElementKey = $(event.currentTarget)
      .next('.form-element')
      .data('key');

    this.referencedAssetField.trigger('dc:upload:setFormFields', {
      formData: formData.filter(f => f.name.includes(formElementKey) || !f.name.includes('thing')),
      allFiles: true
    });
    $(event.currentTarget)
      .html(buttonHtml)
      .removeClass('disabled');
    this.showNotice($(event.currentTarget), 'Attribut wurde übernommen!');
  }
  showNotice(target, text) {
    let notice = $('<span class="copy-attribute-notice">' + text + '</span>');
    $(notice).appendTo(target);
    setTimeout(
      function() {
        notice.fadeOut('fast', function() {
          notice.remove();
        });
      }.bind(this),
      1000
    );
  }
  addCopyAttributeButtons(container) {
    let formFields = $(container)
      .find('> fieldset > .form-element, > .form-element')
      .addBack('.form-element');

    let button = $(
      '<button class="copy-attribute-to-all" title="für alle Bilder übernehmen"><i class="fa fa-clone" aria-hidden="true"></i></button>'
    );

    button.insertBefore(formFields);
  }
  triggerSyncWithContentUploader(event = null) {
    let key;

    if (event)
      key = $(event.currentTarget)
        .find('> .form-element')
        .data('key');

    this.referencedAssetField.trigger('dc:upload:syncWithForm', { key: key, locale: event ? this.activeLocale : null });
  }
  importAttributeValues(event, data = null) {
    event.preventDefault();

    if (!data || !data.attributes) return;
    if (!data || !data.locale) this.form.get(0).reset();

    let groupedAttributes = this.groupAttributeValues(data.attributes, data.locale);

    for (let key in groupedAttributes) {
      this.form
        .find('[data-key="' + key + '"]')
        .find(window.EDITORSELECTORS.join(', '))
        .trigger('dc:import:data', {
          label: key.getKey(),
          value: typeof groupedAttributes[key] == 'string' ? groupedAttributes[key].trim() : groupedAttributes[key],
          locale: data.locale || 'de',
          force: true
        });
    }
  }
  groupAttributeValues(values, locale = null) {
    let groupedValues = {};

    console.log(values);

    if (!values || !values.length) return groupedValues;

    values.forEach(v => {
      if (locale && (!v.name.includes('translations') || !v.name.includes(locale))) return;

      let key = v.name.normalizeKey();

      if (groupedValues[key] || v.value.isUuid()) {
        if (!Array.isArray(groupedValues[key])) groupedValues[key] = [groupedValues[key]].filter(Boolean);

        groupedValues[key].push(v.value);
      } else groupedValues[key] = v.value;
    });

    return groupedValues;
  }
  setReferencedAssetField() {
    const id = this.form
      .closest('.reveal.new-content-reveal')
      .find('.file-for-upload')
      .data('id');
    const referenceField = $('.content-upload-form > .file-for-upload[data-id="' + id + '"]');
    if (referenceField.length) this.referencedAssetField = referenceField;
  }
  createNextAssetButton() {
    this.nextAssetButton = $(
      '<a href="#" class="next-asset-button button-prime"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>'
    ).insertAfter(this.reveal);
    this.nextAssetButton.on('click', this.nextAssetForm.bind(this));
  }
  createPrevAssetButton() {
    this.prevAssetButton = $(
      '<a href="#" class="prev-asset-button button-prime"><i class="fa fa-arrow-left" aria-hidden="true"></i></a>'
    ).insertBefore(this.reveal);
    this.prevAssetButton.on('click', this.prevAssetForm.bind(this));
  }
  updateNavigationButtons(event) {
    event && event.preventDefault();

    if (this.referencedAssetField.siblings('.file-for-upload').length) {
      if (!this.nextAssetButton) this.createNextAssetButton();
      if (!this.prevAssetButton) this.createPrevAssetButton();
    }

    if (this.nextAssetButton && this.prevAssetButton) {
      if (this.referencedAssetField.is(':last-of-type')) this.nextAssetButton.hide();
      else this.nextAssetButton.show();

      if (this.referencedAssetField.is(':first-of-type')) this.prevAssetButton.hide();
      else this.prevAssetButton.show();
    }
  }
  nextAssetForm(event) {
    event.preventDefault();
    this.reveal.foundation('close');
    let nextAsset = this.referencedAssetField.next('.file-for-upload');

    if (nextAsset && nextAsset.length)
      $('.reveal.new-content-reveal#' + nextAsset.find('.edit-upload-button').data('open')).foundation('open');
  }
  prevAssetForm(event) {
    event.preventDefault();
    this.reveal.foundation('close');
    let prevAsset = this.referencedAssetField.prev('.file-for-upload');

    if (prevAsset && prevAsset.length)
      $('.reveal.new-content-reveal#' + prevAsset.find('.edit-upload-button').data('open')).foundation('open');
  }
  updateForm() {
    this.updateCrumbs();
    this.updateWarningLevel();
    let activeFieldset = this.form.find('fieldset.active');
    if (
      (!activeFieldset.hasClass('iframe') && !activeFieldset.hasClass('no-search-warning')) ||
      activeFieldset.hasClass('template')
    )
      this.form.find('.search-warning').show();
    else this.form.find('.search-warning').hide();
    if (activeFieldset.hasClass('template') || activeFieldset.hasClass('no-search-warning'))
      $.rails.enableFormElements(this.form);
    else if (this.form.hasClass('disabled')) $.rails.disableFormElements(this.form);
  }
  checkSelectedAsset(event) {
    event.stopPropagation();
    if (!$(event.target).siblings('.form-element').length) this.next(event);
  }
  changeTranslation(target) {
    this.activeLocale = $(target).data('locale');
    $(target)
      .closest('.translated-attribute-locales')
      .find('.translated-attribute-locale')
      .removeClass('active');
    $(target).addClass('active');
    this.form.find('.translated-attribute.active').removeClass('active');
    this.form
      .find('.translated-attribute.' + $(target).data('locale'))
      .addClass('active')
      .trigger('dc:remote:render');
  }
  next(event) {
    event.preventDefault();
    let activeFieldset = this.form.find('fieldset.active');
    if (this.form.hasClass('validation-form')) {
      activeFieldset.trigger('dc:form:validate', {
        successCallback: () => {
          this.goTo(
            undefined,
            this.form.find('fieldset').index(
              this.form
                .find('fieldset.active')
                .nextAll('fieldset')
                .first()
            )
          );
        }
      });
    } else {
      this.goTo(
        undefined,
        this.form.find('fieldset').index(
          this.form
            .find('fieldset.active')
            .nextAll('fieldset')
            .first()
        )
      );
    }
  }
  prev(event) {
    event.preventDefault();
    this.goTo(
      undefined,
      this.form.find('fieldset').index(
        this.form
          .find('fieldset.active')
          .prevAll('fieldset')
          .first()
      )
    );
  }
  goTo(event, data) {
    if (event) event.preventDefault();
    if (
      this.form.find('fieldset.active').hasClass('template') &&
      this.form.find(':input[name="template"]').val() !== null &&
      this.form.find(':input[name="template"]').val() != this.form.data('template')
    ) {
      this.renderContentForm();
    }
    let index = data !== undefined ? data : event && $(event.target).data('index');
    this.form.find('fieldset.active').removeClass('active');
    this.form
      .find('fieldset:eq(' + index + ')')
      .addClass('active')
      .trigger('dc:remote:render');
    if (this.form.find('fieldset.active').hasClass('template') || this.form.find('fieldset.active').hasClass('iframe'))
      this.form.closest('.reveal:not(.full)').foundation('_updatePosition');
    this.updateForm();
  }
  updateWarningLevel() {
    if (this.form.find('fieldset.active').hasClass('template'))
      this.form
        .find('> .search-warning')
        .removeClass('alert')
        .addClass('warning');
    else
      this.form
        .find('> .search-warning')
        .removeClass('warning')
        .addClass('alert');
  }
  updateCrumbs() {
    this.crumbs.html(
      this.form
        .find('fieldset.active')
        .prevAll('fieldset')
        .get()
        .reverse()
        .map((elem, i) => {
          return (
            '<a class="form-crumb-link" data-index="' +
            i +
            '">' +
            $(elem)
              .find('legend')
              .html() +
            '</a>'
          );
        })
        .concat([this.form.find('fieldset.active legend').html()])
        .join(' <i class="fa fa-angle-right" aria-hidden="true"></i> ')
    );
  }
  renderContentForm() {
    this.form.find('.search-warning').hide();
    this.form
      .find('fieldset:not(.template)')
      .trigger('dc:html:remove')
      .remove();
    this.form.find('.translated-attribute-locales, .form-thumbnail').remove();
    this.form
      .find('.buttons')
      .before(
        '<fieldset class="content-fields"><div class="form-loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div></fieldset>'
      );
    $.rails.disableFormElements(this.form);
    let template = this.form.find(':input[name="template"]').val();
    let params = this.form.data();
    params['template'] = template;
    params['key'] = this.id;
    $.ajax({
      url: '/things/new',
      method: 'GET',
      data: params,
      dataType: 'script',
      contentType: 'application/json'
    }).done(data => {
      this.form.data('template', template);
      this.updateForm();
    });
  }
  resetForm(_) {
    this.form.find(':input').blur();
    $.rails.enableFormElements(this.form);
    this.form.find('.single_error').remove();
    this.form.removeData('template');
    this.changeTranslation(this.form.find('.translated-attribute-locale[data-locale="' + this.locale + '"]'));
    this.goTo(undefined, this.form.find('fieldset').index(this.form.find('fieldset').first()));
  }
  updateLocales(event) {
    this.locale = $(event.target).val();
    this.updateLocalesRecursive();
  }
  updateLocalesRecursive(container = this.form) {
    $(container)
      .find('.object-browser')
      .each((i, elem) => {
        if ($(elem).data('locale') != this.locale)
          $(elem)
            .data('locale', this.locale)
            .trigger('dc:locale:changed');
      });
    $(container)
      .find('.remote-render')
      .each((i, elem) => {
        if ($(elem).data('remote-options').locale !== undefined) $(elem).data('remote-options').locale = this.locale;
      });
    $(container)
      .find('.form-crumbs .locale, form.multi-step fieldset legend .locale')
      .each((i, elem) => {
        if ($(elem).text() != this.locale) $(elem).text('(' + this.locale + ')');
      });
    $(container)
      .find(':input[name="locale"]')
      .each((i, elem) => {
        if ($(elem).val() != this.locale) $(elem).val(this.locale);
      });
    $(container)
      .find('form.multi-step')
      .each((i, elem) => {
        if ($(elem).data('locale') != this.locale) $(elem).data('locale', this.locale);
      });
    $(container)
      .find('.button.show-objectbrowser, .new-content-button')
      .each((i, elem) => {
        this.updateLocalesRecursive($('#' + ($(elem).data('open') || $(elem).data('toggle'))));
      });
  }
}

module.exports = NewContentDialog;
