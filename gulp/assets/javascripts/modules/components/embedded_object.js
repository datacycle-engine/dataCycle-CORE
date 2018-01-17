var ConfirmationHelper = require('./../helpers/confirmation_helper');

// Embedded Object Module
var EmbeddedObject = function (selector) {
  this.element = selector;
  this.id = this.element.prop('id');
  this.index = this.element.children('.content-object-item').length;
  this.language = this.element.data('language') || 'de';
  this.key = this.element.data('key');
  this.label = this.element.data('label');
  this.definition = this.element.data('definition');
  this.options = this.element.data('options');
  this.max = this.element.data('max') || 0;
  this.min = this.element.data('min') || 0;
  this.write = this.element.data('write') || true;
  this.url = '/contents';

  this.setup();
};

EmbeddedObject.prototype.setup = function () {
  if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max)) $(this.element).children('#add_' + this.id).show();

  this.element.off('import-data').on('import-data', function (event, data) {
    var ids = this.element.children('.content-object-item').map(function (index, elem) {
      return $(elem).data('id');
    }).get();

    if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max) && ids.indexOf(data.ids[0]) === -1) {
      this.element.children('#add_' + this.id).prop('disabled', true).find('.fa').css('display', 'inline-block');
      $.ajax({
        url: this.url + '/render_embedded_object',
        method: 'POST',
        data: JSON.stringify({
          index: this.index,
          language: this.language,
          embedded_object_id: '#' + this.id,
          key: this.key,
          definition: this.definition,
          options: this.options,
          id: data.ids
        }),
        contentType: 'application/json'
      }).done(function (data) {
        this.index++;
        this.update();
        this.addEventHandlers();
      }.bind(this));
    } else if (this.write && this.max != 0 && ids.indexOf(data.ids[0]) === -1) {
      ConfirmationHelper.showConfirmation(this.element, event, "Maximalanzahl: " + this.max, false);
    }
  }.bind(this));

  this.addEventHandlers();
};

EmbeddedObject.prototype.addEventHandlers = function () {
  var self = this;

  this.element.children('#add_' + this.id).off('click').on('click', this.renderEmbeddedObject.bind(this));

  this.element.children('.content-object-item').each(function () {
    $(this).children('.removeContentObject').off('click').on('click', function (event) {
      event.preventDefault();
      $(this).closest('.content-object-item').remove();
      self.update();
    });
  });
};

EmbeddedObject.prototype.renderEmbeddedObject = function () {
  this.element.children('#add_' + this.id).prop('disabled', true).find('.fa').css('display', 'inline-block');
  $.ajax({
    url: this.url + '/new_embedded_object',
    method: 'POST',
    data: JSON.stringify({
      index: this.index,
      language: this.language,
      embedded_object_id: '#' + this.id,
      key: this.key,
      definition: this.definition,
      options: this.options
    }),
    contentType: 'application/json'
  }).done(function (data) {
    this.index++;
    this.update();
    this.addEventHandlers();
  }.bind(this));
};

EmbeddedObject.prototype.update = function () {
  var self = this;
  if (this.max != 0 && this.element.children('.content-object-item').length >= this.max) {
    this.element.children('#add_' + this.id).hide();
  } else if (this.write) {
    this.element.children('#add_' + this.id).show();
  }

  if (this.min != 0 && this.element.children('.content-object-item').length <= this.min) {
    this.element.children('.content-object-item').children('.removeContentObject').hide();
  } else if (this.write) {
    this.element.children('.content-object-item').children('.removeContentObject').show();
  }
};

module.exports = EmbeddedObject;
