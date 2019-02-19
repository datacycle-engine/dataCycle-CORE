// Ajax Callback Queue
var NewContentDialog = function(form) {
  this.form = $(form);
  this.next_button = this.form.find('.next');
  this.prev_button = this.form.find('.prev');
  this.crumbs = this.form.find('.form-crumbs');
  this.id = this.form.closest('.new-content-form').attr('id');
  this.locale = this.form.find(':input[name="locale"]').val();
  this.initEventHandlers();
  this.updateForm();
};

NewContentDialog.prototype.initEventHandlers = function() {
  if (this.form.find('fieldset.active').length == 0)
    this.form
      .find('fieldset')
      .first()
      .addClass('active');

  this.next_button.on('click', this.next.bind(this));
  this.prev_button.on('click', this.prev.bind(this));
  this.form.on('click', '.form-crumb-link', this.goTo.bind(this));
  this.form.on('reset.dc.form', this.resetForm.bind(this));
  this.form.on('change', ':input[name="locale"]', this.updateLocales.bind(this));
  this.form.on('goto.dc.multistep', this.goTo.bind(this));
};

NewContentDialog.prototype.updateForm = function() {
  this.updateCrumbs();
  this.updateWarningLevel();
  let active_fieldset = this.form.find('fieldset.active');
  if (
    (!active_fieldset.hasClass('iframe') && !active_fieldset.hasClass('no-search-warning')) ||
    active_fieldset.hasClass('template')
  )
    this.form.find('.callout').show();
  else this.form.find('.callout').hide();
};

NewContentDialog.prototype.next = function(event) {
  event.preventDefault();
  let active_fieldset = this.form.find('fieldset.active');

  this.form.trigger(
    'goto.dc.multistep',
    this.form.find('fieldset').index(this.form.find('fieldset.active').next('fieldset'))
  );

  if (this.form.hasClass('validation-form'))
    active_fieldset.find('.validation-container').trigger('validate.dc.formfield');
};

NewContentDialog.prototype.prev = function(event) {
  event.preventDefault();

  this.form.trigger(
    'goto.dc.multistep',
    this.form.find('fieldset').index(this.form.find('fieldset.active').prev('fieldset'))
  );
};

NewContentDialog.prototype.goTo = function(event, data) {
  event.preventDefault();

  if (
    this.form.find('fieldset.active').hasClass('template') &&
    this.form.find(':input[name="template"]').val() != this.form.data('template')
  ) {
    this.renderContentForm();
  }

  let index = data !== undefined ? data : $(event.target).data('index');
  this.form.find('fieldset.active').removeClass('active');
  this.form.find('fieldset:eq(' + index + ')').addClass('active');

  if (this.form.find('fieldset.active').hasClass('template') || this.form.find('fieldset.active').hasClass('iframe'))
    this.form.closest('.reveal').foundation('open');

  this.updateForm();
};

NewContentDialog.prototype.updateWarningLevel = function() {
  if (this.form.find('fieldset.active').hasClass('template'))
    this.form
      .find('> .callout')
      .removeClass('alert')
      .addClass('warning');
  else
    this.form
      .find('> .callout')
      .removeClass('warning')
      .addClass('alert');
};

NewContentDialog.prototype.updateCrumbs = function() {
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
};

NewContentDialog.prototype.renderContentForm = function() {
  this.form.find('.callout').hide();
  this.form
    .find('fieldset:not(.template)')
    .trigger('remove.dc.html')
    .remove();
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
};

NewContentDialog.prototype.resetForm = function(event) {
  this.form.find(':input').blur();
  this.form.find('fielset.active').removeClass('active');

  this.form
    .find('fielset')
    .first()
    .addClass('active');

  $.rails.enableFormElements(this.form);
  this.form.find('.single_error').remove();
  this.form[0].reset();
};

NewContentDialog.prototype.updateLocales = function(event) {
  this.locale = $(event.target).val();
  this.updateLocalesRecursive();
};

NewContentDialog.prototype.updateLocalesRecursive = function(container = this.form) {
  $(container)
    .find('.object-browser')
    .each((i, elem) => {
      if ($(elem).data('locale') != this.locale)
        $(elem)
          .data('locale', this.locale)
          .trigger('changed.dc.locale');
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
};

module.exports = NewContentDialog;
