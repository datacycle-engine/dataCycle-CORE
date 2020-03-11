var ConfirmationModal = require('./confirmation_modal');

// Asset Selector
class AssetSelector {
  constructor(selector) {
    this.reveal = $(selector);
    this.contentUploaderId = this.reveal.data('content-uploader-id');
    this.assetList = this.reveal.find('ul.asset-list');
    this.selectButton = this.reveal.find('.select-asset-link');
    this.multiSelect = $('#' + this.reveal.data('multi-select'));
    this.selectedAssetIds = [];
    this.page = 1;
    this.loading = false;
    this.requests = [];
    this.total = 0;
    this.per = 25;
    this.lastAssetType = '';
    this.assets = [];
    this.init();
  }
  init() {
    this.reveal.addClass('initialized');
    this.reveal.on('open.zf.reveal', _ => this.loadAssets(false));
    this.assetList.on('click', 'li:not(.locked)', this.clickOnAsset.bind(this));
    this.reveal.on('click', '.select-asset-link:not([disabled])', this.selectAssets.bind(this));
    this.assetList.on('dc:asset_list:changed', this.updateButtons.bind(this));
    this.assetList.parent().on('scroll', this.loadMoreOnScroll.bind(this));
  }
  loadMoreOnScroll(event) {
    event.preventDefault();
    event.stopPropagation();

    if (
      this.assetList[0].scrollHeight - this.assetList.parent().scrollTop() - 200 <=
        this.assetList.parent().outerHeight() &&
      !this.loading &&
      this.assetList.children('li').length < this.total
    ) {
      this.loadAssets();
    }
  }
  loadAssets(append = true) {
    let loader = '<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>';
    if (!append) {
      this.page = 1;
      this.assetList.html(loader);
    } else this.assetList.append(loader);
    this.selectButton.attr('disabled', true);
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
          html_target: this.assetList.prop('id'),
          types: this.assetList.data('asset-types'),
          selected: this.selectedAssetIds,
          page: this.page,
          last_asset_type: this.lastAssetType,
          append: append
        },
        dataType: 'script',
        contentType: 'application/json'
      }).always((data, text, jqXHR) => {
        this.requests = this.requests.filter(r => r != jqXHR);
      })
    );
  }
  updateButtons(event, data) {
    if (data && data.assets && data.assets.length) {
      if (data.append) this.assets = this.assets.concat(data.assets);
      else this.assets = data.assets;
    }

    if (data !== undefined) {
      if (data.selected && data.selected.length && data.total != 0)
        this.selectButton.attr('disabled', false).data('value', data.selected[0]);
      if (data.total !== undefined) this.total = data.total;
      if (data.page !== undefined) this.page = data.page + 1;
      if (data.last_asset_type !== undefined) this.lastAssetType = data.last_asset_type;
    }
    if (
      this.assetList.children('li').length < this.total &&
      this.assetList
        .children('li')
        .last()
        .offset().top -
        this.assetList.offset().top <
        this.assetList.parent().outerHeight()
    ) {
      this.loadAssets();
    } else {
      this.loading = false;
    }
  }
  clickOnAsset(event) {
    if (
      $(event.target).closest('.asset-file-link-tag').length == 0 &&
      $(event.target).closest('.asset-destroy').length == 0 &&
      $(event.target).closest('.asset-duplicate-warning').length == 0
    ) {
      if ($(event.currentTarget).hasClass('active')) {
        $(event.currentTarget).removeClass('active');

        if (this.multiSelect) {
          this.selectedAssetIds = this.selectedAssetIds.filter(v => v !== $(event.currentTarget).data('id'));
          if (!this.selectedAssetIds.length) this.selectButton.attr('disabled', true).removeData('value');
        } else {
          $(event.currentTarget)
            .siblings('li')
            .removeClass('active');
          this.selectedAssetIds = [];
          this.selectButton.attr('disabled', true).removeData('value');
        }
      } else {
        $(event.currentTarget).addClass('active');

        if (this.multiSelect) {
          this.selectedAssetIds.push($(event.currentTarget).data('id'));
        } else {
          $(event.currentTarget)
            .siblings('li')
            .removeClass('active');
          this.selectedAssetIds = [$(event.currentTarget).data('id')];
        }
        this.selectButton.attr('disabled', false).data('value', $(event.currentTarget).data('id'));
      }
    }
  }
  setAssetId(_, data) {
    if (data && data.id) this.selectedAssetIds = [data.id];
  }
  selectAssets(event) {
    event.preventDefault();

    if (this.contentUploaderId) {
      $('#' + this.contentUploaderId).trigger('dc:upload:setIds', {
        assets: this.assets.filter(a => this.selectedAssetIds.includes(a.id))
      });
    }
    this.reveal.foundation('close');
  }
  deselect(event) {
    event.preventDefault();
    $(event.target)
      .closest('li')
      .remove();
  }
}

module.exports = AssetSelector;
