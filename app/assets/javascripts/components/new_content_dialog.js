import QuillHelpers from './../helpers/quill_helpers';
import ConfirmationModal from './../components/confirmation_modal';
import UuidHelper from './../helpers/uuid_helper';
import ObserverHelpers from '../helpers/observer_helpers';

class NewContentDialog {
  constructor(form) {
    form.dcNewContentDialog = true;
    this.form = $(form);
    this.nextButton = this.form.find('.next');
    this.prevButton = this.form.find('.prev');
    this.resetButton = this.form.find('.button.reset');
    this.crumbs = this.form.find('.form-crumbs');
    this.contentUploader = this.form.data('content-uploader');
    this.$formWrapper = this.form.closest('.new-content-form');
    this.id = this.$formWrapper.attr('id');
    this.locale = this.form.find(':input[name="locale"]').val() || 'de';
    this.reveal = this.form.closest('.reveal.new-content-reveal');
    this.primaryAttributeKey = this.form.data('primary-attribute-key');
    this.templateTranslationPlural = this.form.data('template-translation');
    this.referencedAssetField;
    this.nextAssetButton;
    this.prevAssetButton;
    this.translatedFieldInitObserver = new MutationObserver(this.initTranslatableField.bind(this));
    this.changeObserver = new MutationObserver(this._checkForChangedFormData.bind(this));

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
    if (this.form.find('fieldset.active').length == 0) this.form.find('fieldset').first().addClass('active');
    this.nextButton.on('click', this.next.bind(this));
    this.prevButton.on('click', this.prev.bind(this));
    this.form.on('click', '.form-crumb-link', this.goTo.bind(this));
    this.form.on('reset', this.resetForm.bind(this));
    this.form.on('change', ':input[name="locale"]', this.updateLocales.bind(this));
    this.form.on('dc:multistep:goto', this.goTo.bind(this));
    this.form.on('keypress', event => {
      if (event.which == 13 && this.form.find('fieldset.active:not(:last-of-type)').length) {
        event.preventDefault();
        this.next(event);
      }
    });
    this.form.on('click', '.copy-attribute-to-all', this.copySingleToAllReferenceFields.bind(this));
    this.form.find('.translatable-attribute.active').trigger('dc:remote:render');

    if (this.referencedAssetField) {
      this.updateNavigationButtons();
      this.addCopyAttributeButtons(this.form);

      this.reveal.on('open.zf.reveal', event => {
        this.form.trigger('dc:form:enable');
        this.updateNavigationButtons(event);
      });

      this.referencedAssetField.on('dc:form:uploadedFilesChanged', this.updateNavigationButtons.bind(this));
      this.referencedAssetField.on('dc:form:importAttributeValues', this.importAttributeValues.bind(this));
      this.form.on('dc:form:submitWithoutRedirect', this.copyToReferenceField.bind(this));
      this.form.find('.set-all-attributes').on('click', this.copyToAllReferenceFields.bind(this));
      this.translatedFieldInitObserver.observe(this.form.get(0), ObserverHelpers.changedClassWithSubtreeConfig);

      if (this.$formWrapper[0].classList.contains('remote-rendered')) this.triggerSyncWithContentUploader();
      else this.changeObserver.observe(this.$formWrapper[0], ObserverHelpers.changedClassConfig);
    }
  }
  _checkForChangedFormData(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'attributes') continue;

      if (
        mutation.target.classList.contains('remote-rendered') &&
        (!mutation.oldValue || mutation.oldValue.includes('remote-rendering'))
      )
        this.triggerSyncWithContentUploader();
    }
  }
  initTranslatableField(mutations) {
    for (const mutation of mutations) {
      if (
        mutation.target.classList.contains('dc-import-data') &&
        !mutation.target.classList.contains('triggered-sync-with-uploader')
      ) {
        mutation.target.classList.add('triggered-sync-with-uploader');
        const formElement = mutation.target.closest('.form-element');

        this.addCopyAttributeButtons(formElement);
        this.triggerSyncWithContentUploader(formElement);
      }
    }
  }
  copyToReferenceField(event, config = {}) {
    event.preventDefault();

    QuillHelpers.updateEditors(this.form);
    let formData = this.form.serializeArray();

    if (config && config.allFiles) this.reveal.foundation('close');
    else this.nextAssetForm(event);

    this.processFormData(formData, null, config && config.allFiles, config && config.copyPrimary);
  }
  async copyToAllReferenceFields(event) {
    const target = event.currentTarget;

    if (this.primaryAttributeKey) {
      new ConfirmationModal({
        text: await I18n.translate('frontend.upload.confirm_all_to_all_html', {
          label: target.dataset.primaryAttributeLabel,
          template: this.templateTranslationPlural
        }),
        confirmationText: await I18n.translate('common.yes'),
        cancelText: await I18n.translate('common.no'),
        confirmationClass: 'warning',
        cancelable: true,
        confirmationCallback: () => this.form.trigger('submit', { allFiles: true, copyPrimary: true }),
        cancelCallback: () => this.form.trigger('submit', { allFiles: true })
      });
    } else {
      this.form.trigger('submit', { allFiles: true });
    }
  }
  async copySingleToAllReferenceFields(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    const $target = $(event.currentTarget);
    const formElement = $target.next('.form-element');
    const formElementKey = formElement.data('key');

    if (formElementKey.includes(`[${this.primaryAttributeKey}]`)) {
      new ConfirmationModal({
        text: await I18n.translate('frontend.upload.confirm_single_to_all_html', {
          label: formElement.data('label'),
          template: this.templateTranslationPlural
        }),
        confirmationText: await I18n.translate('common.yes'),
        cancelText: await I18n.translate('common.no'),
        confirmationClass: 'warning',
        cancelable: true,
        confirmationCallback: () => this.processSingleFormData(formElementKey, $target)
      });
    } else {
      this.processSingleFormData(formElementKey, $target);
    }
  }
  processSingleFormData(formElementKey, target) {
    target.addClass('disabled');

    QuillHelpers.updateEditors(this.form);
    let formData = this.form.serializeArray();
    formData = formData.filter(f => f.name.includes(formElementKey) || !f.name.includes('thing'));

    this.processFormData(formData, target, true, true);
  }
  processFormData(formData, target = null, allFiles = false, copyPrimary = false) {
    let requests = [];

    formData.forEach((v, i) => {
      if (v && UuidHelper.isUuid(v.value)) {
        const promise = DataCycle.httpRequest({
          url: `/api/v4/universal/${v.value}`,
          method: 'POST',
          data: { fields: 'name,skos:prefLabel' }
        });

        promise.then(data => {
          v.text =
            data &&
            data['@graph'] &&
            data['@graph'][0] &&
            (data['@graph'][0]['skos:prefLabel'] || data['@graph'][0].name);
        });

        requests.push(promise);
      }
    });

    Promise.all(requests).then(
      _data => this.setUploaderFormFields(formData, target, allFiles, copyPrimary),
      _error => this.setUploaderFormFields(formData, target, allFiles, copyPrimary)
    );
  }
  setUploaderFormFields(formData, target = null, allFiles = false, copyPrimary = false) {
    this.referencedAssetField.trigger('dc:upload:setFormFields', {
      formData: formData,
      allFiles: allFiles,
      primaryAttributeKey: copyPrimary ? null : this.primaryAttributeKey
    });

    if (target) {
      target.removeClass('disabled');
      this.showNotice(target, 'Attribut wurde übernommen!');
    }
  }
  showNotice(target, text) {
    let notice = $('<span class="copy-attribute-notice">' + text + '</span>');
    $(notice).appendTo(target);
    setTimeout(
      function () {
        notice.fadeOut('fast', function () {
          notice.remove();
        });
      }.bind(this),
      1000
    );
  }
  addCopyAttributeButtons(container) {
    const formFields = $(container)
      .find('> fieldset > .form-element, > .form-element')
      .addBack('.form-element')
      .filter(
        (_i, item) =>
          !$(item).prev('.copy-attribute-to-all').length &&
          !$(item).parents('.form-element').last().prev('.copy-attribute-to-all').length
      );

    let button = $(
      `<button class="copy-attribute-to-all button-prime small" title="dieses Attribut für alle ${this.templateTranslationPlural} übernehmen"><span class="copy-icon fa-stack"><i class="fa fa-clone"></i><i class="fa fa-arrow-right fa-stack-1x"></i></span><i class="fa loading-icon fa-spinner fa-fw fa-spin"></i></button>`
    );

    button.insertBefore(formFields);

    if (this.primaryAttributeKey && this.primaryAttributeKey.length)
      formFields
        .filter(`[data-key*="[${this.primaryAttributeKey}]"]`)
        .prev('.copy-attribute-to-all')
        .addClass('primary-attribute-button');
  }
  triggerSyncWithContentUploader(target = null) {
    let key;
    const locale = this.form.find('> .available-attribute-locales .list-items > li.active a').data('locale');

    if (target) key = target.dataset.key;

    this.referencedAssetField.trigger('dc:upload:syncWithForm', {
      key: key,
      locale: target ? locale : null
    });
  }
  importAttributeValues(event, data = null) {
    event.preventDefault();

    if (!data || !data.attributes) return;
    if (!data || !data.locale) this.form.get(0).reset();

    let groupedAttributes = this.groupAttributeValues(data.attributes, data.locale);

    for (let key in groupedAttributes) {
      this.form
        .find('[data-key="' + key + '"]')
        .find(DataCycle.config.EditorSelectors.join(', '))
        .triggerHandler('dc:import:data', {
          value: typeof groupedAttributes[key] == 'string' ? groupedAttributes[key].trim() : groupedAttributes[key],
          locale: data.locale || 'de',
          force: true
        });
    }
  }
  groupAttributeValues(values, locale = null) {
    let groupedValues = {};

    if (!values || !values.length) return groupedValues;

    values.forEach(v => {
      if (locale && (!v.name.includes('translations') || !v.name.includes(locale))) return;

      let key = v.name.normalizeKey();

      if (groupedValues[key] || UuidHelper.isUuid(v.value)) {
        if (!Array.isArray(groupedValues[key])) groupedValues[key] = [groupedValues[key]].filter(Boolean);

        groupedValues[key].push(v.value);
      } else groupedValues[key] = v.value;
    });

    return groupedValues;
  }
  setReferencedAssetField() {
    const id = this.form.closest('.reveal.new-content-reveal').find('.file-for-upload').data('id');
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
    if (event) event.preventDefault();

    if (this.referencedAssetField.siblings('.file-for-upload').length) {
      if (!this.nextAssetButton) this.createNextAssetButton();
      if (!this.prevAssetButton) this.createPrevAssetButton();

      this.form.addClass('show-copy-attribute-to-all');
    } else {
      this.form.removeClass('show-copy-attribute-to-all');
    }

    if (this.nextAssetButton && this.prevAssetButton) {
      if (!this.referencedAssetField.next('.file-for-upload.finished').length) this.nextAssetButton.hide();
      else this.nextAssetButton.show();

      if (!this.referencedAssetField.prev('.file-for-upload.finished').length) this.prevAssetButton.hide();
      else this.prevAssetButton.show();
    }
  }
  nextAssetForm(event) {
    event.preventDefault();
    this.reveal.foundation('close');
    let nextAsset = this.referencedAssetField.next('.file-for-upload.finished');

    if (nextAsset && nextAsset.length)
      $('.reveal.new-content-reveal#' + nextAsset.find('.edit-upload-button').data('open')).foundation('open');
  }
  prevAssetForm(event) {
    event.preventDefault();
    this.reveal.foundation('close');
    let prevAsset = this.referencedAssetField.prev('.file-for-upload.finished');

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

    if (activeFieldset.hasClass('template') || activeFieldset.hasClass('no-search-warning')) {
      DataCycle.enableElement(this.form);
    } else if (this.form.hasClass('disabled')) {
      DataCycle.disableElement(this.form);
    }
  }
  next(event) {
    event.preventDefault();
    let activeFieldset = this.form.find('fieldset.active');
    if (this.form.hasClass('validation-form')) {
      activeFieldset.trigger('dc:form:validate', {
        successCallback: () => {
          this.goTo(
            undefined,
            this.form.find('fieldset').index(this.form.find('fieldset.active').nextAll('fieldset').first())
          );
        }
      });
    } else {
      this.goTo(
        undefined,
        this.form.find('fieldset').index(this.form.find('fieldset.active').nextAll('fieldset').first())
      );
    }
  }
  prev(event) {
    event.preventDefault();
    this.goTo(
      undefined,
      this.form.find('fieldset').index(this.form.find('fieldset.active').prevAll('fieldset').first())
    );
  }
  goTo(event, data) {
    if (event) event.preventDefault();

    const $fromSet = this.form.find('fieldset.active');
    const fromIndex = this.form.find('fieldset').index($fromSet);
    const toIndex = data !== undefined ? data : event && $(event.target).data('index');
    const $toSet = this.form.find('fieldset:eq(' + toIndex + ')');

    if (
      $fromSet.hasClass('template') &&
      fromIndex !== toIndex &&
      this.form.data('template') !== this.form.find(':input[name="template"]').val()
    )
      this.renderContentForm();

    $fromSet.removeClass('active');
    $toSet.addClass('active').trigger('dc:remote:render');

    if ($toSet.hasClass('template') || $toSet.hasClass('iframe'))
      this.form.closest('.reveal:not(.full)').foundation('_updatePosition');

    this.updateForm();
  }
  updateWarningLevel() {
    if (this.form.find('fieldset.active').hasClass('template'))
      this.form.find('> .search-warning').removeClass('alert').addClass('warning');
    else this.form.find('> .search-warning').removeClass('warning').addClass('alert');
  }
  updateCrumbs() {
    this.crumbs.html(
      this.form
        .find('fieldset.active')
        .prevAll('fieldset')
        .get()
        .reverse()
        .map((elem, i) => {
          return '<a class="form-crumb-link" data-index="' + i + '">' + $(elem).find('legend').html() + '</a>';
        })
        .concat([this.form.find('fieldset.active legend').html()])
        .join(' <i class="fa fa-angle-right" aria-hidden="true"></i> ')
    );
  }
  renderContentForm() {
    this.form.find('.search-warning').hide();
    this.form.find('fieldset:not(.template)').trigger('dc:html:remove').remove();
    this.form.find('.available-attribute-locales, .form-thumbnail').remove();
    this.form
      .find('.buttons')
      .before(
        '<fieldset class="content-fields"><div class="form-loading"><i class="fa fa-spinner fa-spin fa-fw"></i></div></fieldset>'
      );
    DataCycle.disableElement(this.form);
    let template = this.form.find(':input[name="template"]').val();
    let params = this.form.data();
    params['template'] = template;
    params['key'] = this.id;

    const promise = DataCycle.httpRequest({
      url: '/things/new',
      method: 'GET',
      data: params,
      dataType: 'script',
      contentType: 'application/json'
    });

    promise.then(_data => {
      this.form.data('template', template);
      this.updateForm();
    });

    return promise;
  }
  resetForm(_) {
    this.form.find(':input').blur();
    DataCycle.enableElement(this.form);
    this.form.find('.single_error').remove();
    this.form.removeData('template');
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
        if ($(elem).data('locale') != this.locale) $(elem).data('locale', this.locale).trigger('dc:locale:changed');
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

export default NewContentDialog;
