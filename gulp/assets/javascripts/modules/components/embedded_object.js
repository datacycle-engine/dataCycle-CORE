var ConfirmationModal = require('./../components/confirmation_modal');

// Embedded Object Module
var EmbeddedObject = function (selector) {
  this.element = selector;
  this.page = 1;
  this.id = this.element.prop('id');
  this.language = this.element.data('language') || 'de';
  this.key = this.element.data('key');
  this.label = this.element.data('label');
  this.definition = this.element.data('definition');
  this.options = this.element.data('options');
  this.max = this.element.data('max') || 0;
  this.min = this.element.data('min') || 0;
  this.write = this.element.data('write') || true;
  this.total = this.element.data('total') || 0;
  this.index = this.total;
  this.ids = this.element.data('ids') || [];
  this.active_ids = this.element.data('ids') || [];
  this.per = this.element.data('per') || 5;
  this.url = '/contents';

  this.setup();
};

EmbeddedObject.prototype.setup = function () {
  if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max)) $(this.element).find('> .buttons > #add_' + this.id).show();

  this.element.off('import-data').on('import-data', function (event, data) {
    let page = data.page || 1;

    let new_items = data.ids.diff(this.element.children('.content-object-item').map((index, elem) => $(elem).data('id')).get());

    if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max) && new_items.length > 0) {
      this.render_embedded_objects(new_items, this.index);
    } else if (this.write && this.max != 0 && (ids.length + new_items.length) > this.max) {
      var confirmationModal = new ConfirmationModal("Maximalanzahl: " + this.max);
    }
  }.bind(this));

  this.addEventHandlers();
};

EmbeddedObject.prototype.render_embedded_objects = function (ids, index, update_index = true, page = 1) {
  this.element.find('> .buttons > button').prop('disabled', true).find('.fa').css('display', 'inline-block');
  $.ajax({
    url: this.url + '/render_embedded_object',
    method: 'POST',
    data: JSON.stringify({
      index: index,
      language: this.language,
      key: this.key,
      definition: this.definition,
      options: this.options,
      id: ids,
      page: page
    }),
    contentType: 'application/json'
  }).done(data => {
    if (update_index) this.index += ids.length;
    this.ids = this.ids.concat(ids.diff(this.ids));
    this.active_ids = this.active_ids.concat(ids.diff(this.active_ids));
    if (this.active_ids.diff(this.element.children('.content-object-item').map((index, elem) => $(elem).data('id')).get()).length == 0) {
      this.element.find('> .buttons > #load_more_' + this.id).off('click').remove();
    }
    this.update();
    this.addEventHandlers();
  });
};

EmbeddedObject.prototype.addEventHandlers = function () {
  var self = this;

  this.element.find('> .buttons > #add_' + this.id).off('click').on('click', this.renderEmbeddedObject.bind(this));

  this.element.children('.content-object-item').each((index, element) => {
    $(element).children('.removeContentObject').off('click').on('click', event => {
      event.preventDefault();
      let id = $(event.currentTarget).closest('.content-object-item').data('id');
      this.element.find('input:hidden[value="' + id + '"]').remove();
      this.active_ids = this.active_ids.filter(e => e !== id);
      $(event.currentTarget).closest('.content-object-item').remove();
      self.update();
    });
  });

  this.element.find('> .buttons > #load_more_' + this.id).off('click').on('click', event => {
    event.preventDefault();
    let page = $(event.currentTarget).data('page');

    this.render_embedded_objects(this.ids.slice((page - 1) * this.per, page * this.per), (page - 1) * this.per, false, page);
  });
};

EmbeddedObject.prototype.renderEmbeddedObject = function () {
  this.element.find('> .buttons > button').prop('disabled', true).find('.fa').css('display', 'inline-block');
  $.ajax({
    url: this.url + '/new_embedded_object',
    method: 'POST',
    data: JSON.stringify({
      index: this.index,
      language: this.language,
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
    this.element.find('> .buttons > #add_' + this.id).hide();
  } else if (this.write) {
    this.element.find('> .buttons > #add_' + this.id).show();
  }

  if (this.min != 0 && this.element.children('.content-object-item').length <= this.min) {
    this.element.children('.content-object-item').children('.removeContentObject').hide();
  } else if (this.write) {
    this.element.children('.content-object-item').children('.removeContentObject').show();
  }
};

module.exports = EmbeddedObject;
