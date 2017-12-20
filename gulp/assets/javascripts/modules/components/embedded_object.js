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
  var self = this;
  if (this.write && (this.max == 0 || this.index < this.max) && this.element.find('#add_' + this.id).length == 0) {
    $('<button id="add_' + this.id + '" type="button" class="button addContentObject">' + this.label + ' hinzufügen</button>').appendTo(this.element).on('click', this.render_embedded_object.bind(this));
  }

  this.element.children('.content-object-item').each(function () {
    $(this).children('.removeContentObject').off('click').on('click', function (event) {
      event.preventDefault();
      $(this).closest('.content-object-item').remove();
      self.update();
    });
  });
};

EmbeddedObject.prototype.render_embedded_object = function () {
  $.ajax({
    url: this.url + '/render_embedded_object',
    method: 'POST',
    data: JSON.stringify({
      index: this.index,
      language: this.language,
      embedded_object_id: '#' + this.id,
      key: this.key,
      definition: this.definition,
      can_write: this.write
    }),
    contentType: 'application/json'
  }).done(function (data) {
    this.index++;
    this.update();
  }.bind(this));

};

EmbeddedObject.prototype.update = function () {
  var self = this;
  if (this.max != 0 && this.element.children('.content-object-item').length >= this.max) {
    this.element.find('#add_' + this.id).off('click').remove();
  } else if (this.write && this.element.find('#add_' + this.id).length == 0) {
    $('<button id="add_' + this.id + '" type="button" class="button addContentObject">' + this.label + ' hinzufügen</button>').appendTo(this.element).on('click', this.render_embedded_object.bind(this));
  }

  if (this.min != 0 && this.element.children('.content-object-item').length <= this.min) {
    this.element.children('.content-object-item').children('.removeContentObject').off('click').remove();
  } else if (this.write) {
    this.element.children('.content-object-item').each(function () {
      if ($(this).children('.removeContentObject').length == 0) {
        $('<button type="button" class="button removeContentObject"><i class="fa fa-times"></i></button>').prependTo($(this));
      }
      $(this).children('.removeContentObject').off('click').on('click', function (event) {
        event.preventDefault();
        $(this).closest('.content-object-item').remove();
        self.update();
      });
    });
  }
};


module.exports = EmbeddedObject;
