var ConfirmationHelper = require('./../helpers/confirmation_helper');

// Asset Module
var Asset = function (selector) {
  this.element = selector;
  this.id = this.element.prop('id');
  // this.index = this.element.children('.content-object-item').length;
  // this.language = this.element.data('language') || 'de';
  this.key = this.element.data('key');
  this.label = this.element.data('label');
  this.definition = this.element.data('definition');
  this.options = this.element.data('options');
  this.max = this.element.data('max') || 0;
  this.min = this.element.data('min') || 0;
  this.write = this.element.data('write') || true;
  this.url = '/files/assets';

  this.setup();
};

Asset.prototype.setup = function () {
  console.log(this);
  // this.element.off('import-data').on('import-data', function (event, data) {
  //
  //   var ids = this.element.children('.content-object-item').map(function (index, elem) {
  //     return $(elem).data('id');
  //   }).get();
  //
  //   if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max) && ids.indexOf(data.ids[0]) === -1) {
  //     this.element.children('#add_' + this.id).prop('disabled', true).find('.fa').css('display', 'inline-block');
  //     $.ajax({
  //       url: this.url + '/renderEmbeddedObject',
  //       method: 'POST',
  //       data: JSON.stringify({
  //         index: this.index,
  //         language: this.language,
  //         embedded_object_id: '#' + this.id,
  //         key: this.key,
  //         definition: this.definition,
  //         options: this.options,
  //         id: data.ids
  //       }),
  //       contentType: 'application/json'
  //     }).done(function (data) {
  //       this.index++;
  //       this.update();
  //       this.addEventHandlers();
  //     }.bind(this));
  //   } else if (this.write && this.max != 0 && ids.indexOf(data.ids[0]) === -1) {
  //     ConfirmationHelper.showConfirmation(this.element, event, "Maximalanzahl: " + this.max, false);
  //   }
  // }.bind(this));

  this.addEventHandlers();
};

Asset.prototype.addEventHandlers = function () {
  var self = this;

  this.element.children('#add_' + this.id).off('click').on('click', this.createAsset.bind(this));

  // this.element.children('.content-object-item').each(function () {
  //   $(this).children('.removeContentObject').off('click').on('click', function (event) {
  //     event.preventDefault();
  //     $(this).closest('.content-object-item').remove();
  //     self.update();
  //   });
  // });
};

Asset.prototype.createAsset = function () {
  console.log('juhu');
  this.element.children('#add_' + this.id).prop('disabled', true).find('.fa').css('display', 'inline-block');
  // find file
  file = this.element.children('#' + this.id + '_file').get(0).files[0];
  console.log(file.files);
  var formData = new FormData();
  formData.append("asset[file]", file);
  formData.append("asset[asset_object_id]", this.id);
  formData.append("asset[key]", this.key);
  formData.append("asset[definition]", JSON.stringify(this.definition));
  formData.append("asset[options]", JSON.stringify(this.options));
  console.log(formData);
  console.log(file);
  $.ajax({
    url: this.url + '/new_asset_object',
    method: 'POST',
    data: formData,
    processData: false,  // tell jQuery not to process the data
    contentType: false   // tell jQuery not to set contentType
  }).done(function (data) {
    this.update();
    this.addEventHandlers();
  }.bind(this));
};

Asset.prototype.renderAsset = function () {
  console.log('juhu');
  this.element.children('#add_' + this.id).prop('disabled', true).find('.fa').css('display', 'inline-block');
  $.ajax({
    url: this.url + '/new_asset_object',
    method: 'POST',
    data: JSON.stringify({
      asset_object_id: '#' + this.id,
      key: this.key,
      definition: this.definition,
      options: this.options
    }),
    contentType: 'application/json'
  }).done(function (data) {
    this.update();
    this.addEventHandlers();
  }.bind(this));
};

Asset.prototype.update = function () {
  var self = this;
  console.log('update :)');
  // if (this.max != 0 && this.element.children('.content-object-item').length >= this.max) {
  //   this.element.children('#add_' + this.id).hide();
  // } else if (this.write) {
  //   this.element.children('#add_' + this.id).show();
  // }
  //
  // if (this.min != 0 && this.element.children('.content-object-item').length <= this.min) {
  //   this.element.children('.content-object-item').children('.removeContentObject').hide();
  // } else if (this.write) {
  //   this.element.children('.content-object-item').children('.removeContentObject').show();
  // }
};

module.exports = Asset;
