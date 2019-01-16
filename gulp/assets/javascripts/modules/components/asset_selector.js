// Ajax Callback Queue
var AssetSelector = function(button, asset_selectors) {
  this.button = $(button);
  this.reveal = $('#' + this.button.data('open'));
  this.asset_list = this.reveal.find('ul.asset-list');
  this.select_button = this.reveal.find('.select-asset-link');
  this.hidden_field = $('#' + this.reveal.data('hidden-field-id'));
  this.selected_asset_list = this.hidden_field.siblings('.asset-list');
  this.selected_asset_id = '';
  this.asset_selectors = asset_selectors;

  this.init();
};

AssetSelector.prototype.init = function() {
  this.reveal.on('open.zf.reveal', this.loadAssets.bind(this));

  this.asset_list.on('click', 'li', this.clickOnAsset.bind(this));

  this.reveal.on(
    'click',
    '.select-asset-link:not([disabled])',
    this.selectAssets.bind(this)
  );

  this.selected_asset_list.on(
    'click',
    '.asset-deselect',
    this.deselect.bind(this)
  );
};

AssetSelector.prototype.loadAssets = function(event) {
  this.asset_list.html(
    '<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>'
  );

  this.select_button.attr('disabled', true);

  $.ajax({
    url: '/files/assets',
    method: 'GET',
    data: {
      html_target: this.asset_list.prop('id'),
      types: this.asset_list.data('asset-types'),
      selected: this.selected_asset_id,
      locked_assets: this.asset_selectors
        .filter(selector => {
          return (
            selector.button.data('open') != this.button.data('open') &&
            selector.selected_asset_id != ''
          );
        })
        .map(selector => selector.selected_asset_id)
    },
    dataType: 'script',
    contentType: 'application/json'
  });
};

AssetSelector.prototype.clickOnAsset = function(event) {
  if ($(event.target).closest('.asset-file-link-tag').length == 0) {
    if ($(event.currentTarget).hasClass('active')) {
      $(event.currentTarget)
        .removeClass('active')
        .siblings('li')
        .removeClass('active');
      this.select_button.attr('disabled', true).removeData('value');
    } else {
      $(event.currentTarget)
        .addClass('active')
        .siblings('li')
        .removeClass('active');
      this.select_button
        .attr('disabled', false)
        .data('value', $(event.currentTarget).data('id'));
    }
  }
};

AssetSelector.prototype.selectAssets = function(event) {
  event.preventDefault();

  this.selected_asset_id = this.select_button.data('value');
  this.hidden_field.attr('value', this.selected_asset_id);
  this.selected_asset_list.html(this.asset_list.find('li.active').clone());
  this.reveal.foundation('close');
};

AssetSelector.prototype.deselect = function(event) {
  event.preventDefault();

  this.hidden_field.removeAttr('value');
  this.selected_asset_id = '';
  $(event.target)
    .closest('li')
    .remove();
};

module.exports = AssetSelector;
