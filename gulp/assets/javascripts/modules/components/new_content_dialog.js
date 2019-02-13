// Ajax Callback Queue
var NewContentDialog = function(form) {
  this.form = $(form);
  this.next_button = this.form.find('.next');
  this.prev_button = this.form.find('.prev');
  this.crumbs = this.form.find('.form-crumbs');
  this.id = this.form.closest('.new-content-form').attr('id');
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
};

NewContentDialog.prototype.updateForm = function() {
  this.updateCrumbs();
  this.updateWarningLevel();
  this.form.closest('.reveal').foundation('open');
};

NewContentDialog.prototype.next = function(event) {
  event.preventDefault();

  if (
    this.form.find('fieldset.active').hasClass('template') &&
    this.form.find(':input[name="template"]').val() != this.form.data('template')
  ) {
    this.renderContentForm();
  }

  this.form
    .find('fieldset.active')
    .removeClass('active')
    .next('fieldset')
    .addClass('active');
  this.updateForm();
};

NewContentDialog.prototype.prev = function(event) {
  event.preventDefault();
  this.form
    .find('fieldset.active')
    .removeClass('active')
    .prev('fieldset')
    .addClass('active');
  this.updateForm();
};

NewContentDialog.prototype.goTo = function(event) {
  event.preventDefault();
  this.form.find('fieldset.active').removeClass('active');
  this.form.find('fieldset:eq(' + $(event.target).data('index') + ')').addClass('active');

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
            .text() +
          '</a>'
        );
      })
      .concat([this.form.find('fieldset.active legend').text()])
      .join(' <i class="fa fa-angle-right" aria-hidden="true"></i> ')
  );
};

NewContentDialog.prototype.renderContentForm = function() {
  this.form.find('fieldset:not(.template)').remove();
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

module.exports = NewContentDialog;
