var ConfirmationModal = require('./../components/confirmation_modal');
var Sortable = require('sortablejs');

// Embedded Object Module
var EmbeddedObject = function (selector) {
  this.element = selector;
  this.page = 1;
  this.id = this.element.prop('id');
  this.locale = this.element.data('locale') || 'de';
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
  this.per = this.element.data('per') || 5;
  this.url = '/contents';
  this.sortable;
  this.parent_id = this.element.data('parent-id');
  this.parent_content_type = this.element.data('parent-content-type');

  this.setup();
};

EmbeddedObject.prototype.setup = function () {
  this.sortable = new Sortable(this.element[0], {
    handle: '.draggable-handle',
    draggable: '.content-object-item'
  });

  if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max)) $(this.element).find('> .buttons > #add_' + this.id).show();

  this.element.off('reinit-event-handlers').on('reinit-event-handlers', this.addEventHandlers.bind(this));

  this.element.off('import-data').on('import-data', function (event, data) {
    let page = data.page || 1;

    let new_items = data.ids.diff(this.element.children('.content-object-item').map((index, elem) => $(elem).data('id')).get());

    if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max) && new_items.length > 0) {
      this.renderEmbeddedObjects('render', new_items);
    } else if (this.write && this.max != 0 && (ids.length + new_items.length) > this.max) {
      var confirmationModal = new ConfirmationModal("Maximalanzahl: " + this.max);
    }
  }.bind(this));

  this.addEventHandlers();
};

EmbeddedObject.prototype.renderEmbeddedObjects = function (type, ids = []) {
  this.element.find('> .buttons > button').prop('disabled', true).find('.fa').css('display', 'inline-block');
  $.ajax({
    url: this.url + '/' + type + '_embedded_object',
    method: 'POST',
    data: JSON.stringify({
      index: this.index,
      locale: this.locale,
      key: this.key,
      definition: this.definition,
      options: this.options,
      parent_id: this.parent_id,
      parent_content_type: this.parent_content_type,
      id: ids
    }),
    dataType: 'script',
    contentType: 'application/json'
  }).done(data => {
    this.index++;
    if (ids.length > 0) this.ids = this.ids.concat(ids.diff(this.ids));
    this.update();
    this.addEventHandlers();
  });
};

EmbeddedObject.prototype.addEventHandlers = function () {
  var self = this;

  this.element.find('> .buttons > #add_' + this.id).off('click').on('click', event => {
    this.renderEmbeddedObjects('new');
  });

  this.element.children('.content-object-item').each((index, element) => {
    $(element).children('.removeContentObject').off('click').on('click', event => {
      event.preventDefault();
      let id = $(event.currentTarget).closest('.content-object-item').data('id');
      this.element.find('input:hidden[value="' + id + '"]').remove();
      $(event.currentTarget).closest('.content-object-item').remove();
      self.update();
    });
  });
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

  if (this.element.children('.content-object-item').length == 0) {
    this.element.append('<input type="hidden" value="" id="' + this.id + '_default" name="' + this.key + '[]">');
  } else {
    this.element.find('input[type=hidden]#' + this.id + '_default').remove();
  }
};

module.exports = EmbeddedObject;
