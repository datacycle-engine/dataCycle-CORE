// Ajax Callback Queue
class NewContentDialog {
  constructor(form) {
    this.form = $(form);
    this.next_button = this.form.find('.next');
    this.prev_button = this.form.find('.prev');
    this.reset_button = this.form.find('.button.reset');
    this.crumbs = this.form.find('.form-crumbs');
    this.id = this.form.closest('.new-content-form').attr('id');
    this.locale = this.form.find(':input[name="locale"]').val();
    this.initEventHandlers();
    this.updateForm();
  }
  initEventHandlers() {
    if (this.form.find('fieldset.active').length == 0)
      this.form
        .find('fieldset')
        .first()
        .addClass('active');
    this.next_button.on('click', this.next.bind(this));
    this.prev_button.on('click', this.prev.bind(this));
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
    this.form.on('dc:asset:changed', '.form-element', this.updateThumbnail.bind(this));
    this.form.find('.translated-attribute.active').trigger('dc:remote:render');
  }
  updateForm() {
    this.updateCrumbs();
    this.updateWarningLevel();
    let active_fieldset = this.form.find('fieldset.active');
    if (
      (!active_fieldset.hasClass('iframe') && !active_fieldset.hasClass('no-search-warning')) ||
      active_fieldset.hasClass('template')
    )
      this.form.find('.search-warning').show();
    else this.form.find('.search-warning').hide();
    if (active_fieldset.hasClass('template') || active_fieldset.hasClass('no-search-warning'))
      $.rails.enableFormElements(this.form);
    else if (this.form.hasClass('disabled')) $.rails.disableFormElements(this.form);
  }
  checkSelectedAsset(event) {
    event.stopPropagation();
    if (!$(event.target).siblings('.form-element').length) this.next(event);
  }
  updateThumbnail(event, data) {
    let form_thumbnail = this.form.find('> .form-thumbnail');
    if (data !== undefined && data.thumb !== undefined && form_thumbnail.length) {
      form_thumbnail.attr('src', data.thumb);
    } else if (data !== undefined && data.thumb !== undefined) {
      this.form.append('<img class="form-thumbnail" src="' + data.thumb + '">');
    } else {
      form_thumbnail.remove();
    }
  }
  changeTranslation(target) {
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
    let active_fieldset = this.form.find('fieldset.active');
    if (this.form.hasClass('validation-form')) {
      active_fieldset.trigger('dc:form:validate', {
        success_callback: () => {
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
    if (event !== undefined) event.preventDefault();
    if (
      this.form.find('fieldset.active').hasClass('template') &&
      this.form.find(':input[name="template"]').val() !== null &&
      this.form.find(':input[name="template"]').val() != this.form.data('template')
    ) {
      this.renderContentForm();
    }
    let index = data !== undefined ? data : $(event.target).data('index');
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
  resetForm(event) {
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
