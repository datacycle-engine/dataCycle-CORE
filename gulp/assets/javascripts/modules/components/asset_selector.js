// Ajax Callback Queue
var AssetSelector = function(button, asset_selectors) {
  this.button = $(button);
  this.reveal = $('#' + this.button.data('open'));
  this.asset_list = this.reveal.find('ul.asset-list');
  this.select_button = this.reveal.find('.select-asset-link');
  this.hidden_field = $('#' + this.reveal.data('hidden-field-id'));
  this.selected_asset_list = this.hidden_field.siblings('.asset-list');
  this.selected_asset_id = this.hidden_field.attr('value');
  this.selected_asset_thumb = this.selected_asset_list
    .find('img')
    .first()
    .attr('src');
  this.form_element = this.button.closest('.form-element');
  this.asset_selectors = asset_selectors;
  this.page = 1;
  this.loading = false;
  this.requests = [];
  this.total = 0;
  this.per = 25;
  this.last_asset_type = '';

  this.init();
};

AssetSelector.prototype.init = function() {
  this.reveal.on('open.zf.reveal', event => this.loadAssets(false));
  this.asset_list.on('click', 'li', this.clickOnAsset.bind(this));
  this.reveal.on('click', '.select-asset-link:not([disabled])', this.selectAssets.bind(this));
  this.selected_asset_list.on('click', '.asset-deselect', this.deselect.bind(this));
  this.button.closest('form').on('reset.dc.form', this.resetSelector.bind(this));
  this.asset_list.on('changed.dc.asset_list', this.updateButtons.bind(this));
  this.asset_list.parent().on('scroll', this.loadMoreOnScroll.bind(this));
};

AssetSelector.prototype.loadMoreOnScroll = function(event) {
  if (
    this.asset_list[0].scrollHeight - this.asset_list.parent().scrollTop() - 200 <=
      this.asset_list.parent().outerHeight() &&
    !this.loading &&
    this.asset_list.children('li').length < this.total
  ) {
    this.loadAssets();
  }
};

AssetSelector.prototype.loadAssets = function(append = true) {
  let loader = '<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>';
  if (!append) {
    this.page = 1;
    this.asset_list.html(loader);
  } else this.asset_list.append(loader);
  this.select_button.attr('disabled', true);
  this.loading = true;
  this.requests.forEach(request => {
    request.abort();
    this.requests = this.requests.filter(r => r != request);
  });
  this.requests.push(
    $.ajax({
      url: '/files/assets',
      method: 'GET',
      data: {
        html_target: this.asset_list.prop('id'),
        types: this.asset_list.data('asset-types'),
        selected: this.selected_asset_id,
        locked_assets: this.uniqueLockedAssetIds(),
        page: this.page,
        last_asset_type: this.last_asset_type,
        append: append
      },
      dataType: 'script',
      contentType: 'application/json'
    }).always((data, text, jqXHR) => {
      this.requests = this.requests.filter(r => r != jqXHR);
    })
  );
};

AssetSelector.prototype.updateButtons = function(event, data) {
  if (data !== undefined) {
    if (data.selected !== undefined && data.selected != '')
      this.select_button.attr('disabled', false).data('value', data.selected);
    if (data.total !== undefined) this.total = data.total;
    if (data.page !== undefined) this.page = data.page + 1;
    if (data.last_asset_type !== undefined) this.last_asset_type = data.last_asset_type;
  }

  if (
    this.asset_list.children('li').length < this.total &&
    this.asset_list
      .children('li')
      .last()
      .offset().top -
      this.asset_list.offset().top <
      this.asset_list.parent().outerHeight()
  ) {
    this.loadAssets();
  } else {
    this.loading = false;
  }
};

AssetSelector.prototype.uniqueLockedAssetIds = function() {
  return this.asset_selectors
    .filter(selector => {
      return selector.button.data('open') != this.button.data('open') && selector.selected_asset_id != undefined;
    })
    .map(selector => selector.selected_asset_id);
};

AssetSelector.prototype.clickOnAsset = function(event) {
  if (
    $(event.target).closest('.asset-file-link-tag').length == 0 &&
    $(event.target).closest('.asset-destroy').length == 0
  ) {
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
      this.select_button.attr('disabled', false).data('value', $(event.currentTarget).data('id'));
    }
  }
};

AssetSelector.prototype.updateHiddenField = function(value = undefined) {
  this.selected_asset_id = value;
  this.selected_asset_thumb = this.selected_asset_list
    .find('img')
    .first()
    .attr('src');
  if (value !== undefined) {
    this.hidden_field.val(value);
    this.form_element.trigger('selected.dc.asset', { id: this.selected_asset_id, thumb: this.selected_asset_thumb });
  } else this.hidden_field.removeAttr('value');
  this.form_element.trigger('changed.dc.asset', { id: this.selected_asset_id, thumb: this.selected_asset_thumb });
};

AssetSelector.prototype.selectAssets = function(event) {
  event.preventDefault();

  this.selected_asset_list.html(this.asset_list.find('li.active').clone());
  this.updateHiddenField(this.select_button.data('value'));
  this.reveal.foundation('close');
};

AssetSelector.prototype.deselect = function(event) {
  event.preventDefault();

  $(event.target)
    .closest('li')
    .remove();
  this.updateHiddenField();
};

AssetSelector.prototype.resetSelector = function(event) {
  this.selected_asset_list.empty();
  this.updateHiddenField();
};

module.exports = AssetSelector;
