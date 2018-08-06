// Asset Module
var Asset = function (selector) {
  this.element = selector;
  this.id = this.element.prop('id');
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
  this.addEventHandlers();
};

Asset.prototype.addEventHandlers = function () {
  this.element.find('#add_' + this.id).off('click').on('click', this.createAsset.bind(this));
  this.element.find('.removeAsset').off('click').on('click', this.removeAsset.bind(this));
};

Asset.prototype.createAsset = function () {
  file = this.element.children('#' + this.id + '_file').get(0).files[0];
  if (file != undefined) {
    this.element.children('#add_' + this.id).prop('disabled', true).find('.fa').css('display', 'inline-block');
    var formData = new FormData();
    formData.append("asset[file]", file);
    formData.append("asset[asset_object_id]", this.id);
    formData.append("asset[key]", this.key);
    formData.append("asset[definition]", JSON.stringify(this.definition));
    formData.append("asset[options]", JSON.stringify(this.options));
    $.ajax({
      url: this.url + '/new_asset_object',
      method: 'POST',
      data: formData,
      processData: false, // tell jQuery not to process the data
      contentType: false // tell jQuery not to set contentType
    }).done(function (data) {
      this.update(true);
      this.addEventHandlers();
    }.bind(this));
  }
};

Asset.prototype.removeAsset = function () {
  var formData = new FormData();
  formData.append("asset[asset_object_id]", this.id);
  formData.append("asset[key]", this.key);
  formData.append("asset[definition]", JSON.stringify(this.definition));
  formData.append("asset[options]", JSON.stringify(this.options));
  var item_id = this.element.children('#' + this.id + '_hidden').val();
  $.ajax({
    url: this.url + '/' + item_id + '/remove_asset_object',
    method: 'DELETE',
    data: formData,
    processData: false, // tell jQuery not to process the data
    contentType: false // tell jQuery not to set contentType
  }).done(function (data) {
    this.update(false);
    this.addEventHandlers();
  }.bind(this));
};

Asset.prototype.update = function (asset_exists = false) {

  if (asset_exists && this.write) {
    this.element.children('#add_' + this.id).hide();
    this.element.children('.asset-object').children('.removeAsset').show();
  } else if (this.write) {
    this.element.children('#add_' + this.id).show();
    this.element.children('.asset-object').children('.removeAsset').hide();
  }

};

module.exports = Asset;
