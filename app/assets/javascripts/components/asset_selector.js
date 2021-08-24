import loadingIcon from '../templates/loadingIcon';

class AssetSelector {
  constructor(selector) {
    this.reveal = $(selector);
    this.contentUploaderId = this.reveal.data('content-uploader-id');
    this.hiddenFieldId = this.reveal.data('hidden-field-id');
    this.hiddenFieldKey = this.reveal.data('hidden-field-key');
    this.assetList = this.reveal.find('ul.asset-list');
    this.selectButton = this.reveal.find('.select-asset-link');
    this.multiSelect = this.reveal.data('multi-select');
    this.selectedAssetIds = [];
    this.page = 1;
    this.loading = false;
    this.requests = [];
    this.total = 0;
    this.per = 25;
    this.lastAssetType = '';
    this.assets = [];
    this.editableList = $(`#${this.reveal.data('editable-list-id')}`);
    this.editableFormElement = this.editableList.closest('.form-element');
    this.editButton = $(`#${this.reveal.prop('id')}`);

    this.init();
  }
  init() {
    this.reveal.addClass('initialized');
    this.reveal.on('open.zf.reveal', _ => this.loadAssets(false));
    this.assetList.on('click', 'li:not(.locked)', this.clickOnAsset.bind(this));
    this.reveal.on('click', '.select-asset-link:not(.disabled)', this.selectAssets.bind(this));
    this.assetList.on('dc:asset_list:changed', this.updateButtons.bind(this));
    this.assetList.parent().on('scroll', this.loadMoreOnScroll.bind(this));

    if (this.editableList.length) {
      this.initEdtiableList();
      this.editableList.on('dc:asset_list:changed', this.updateHiddenField.bind(this));
    }
  }
  initEdtiableList() {
    this.editableList.on('click', '.asset-deselect', this.deselectAsset.bind(this));
  }
  deselectAsset(event) {
    event.preventDefault();

    const selectedItem = event.target.closest('li');
    this.selectedAssetIds = this.selectedAssetIds.filter(v => v !== selectedItem.dataset.id);
    selectedItem.remove();

    this.updateHiddenField();
  }
  setSelectedAssets() {
    this.editableList.html(loadingIcon);
    DataCycle.disableElement(this.editButton);
    DataCycle.httpRequest({
      url: '/files/assets',
      method: 'GET',
      data: {
        html_target: this.editableList.prop('id'),
        types: this.editableList.data('asset-types'),
        asset_ids: this.selectedAssetIds
      },
      dataType: 'script',
      contentType: 'application/json'
    }).always((_data, _text, _jqXHR) => {
      DataCycle.enableElement(this.editButton);
    });
  }
  updateHiddenField() {
    if (!this.editableFormElement.length) return;

    this.editableFormElement.children(':hidden').remove();

    if (this.selectedAssetIds && this.selectedAssetIds.length) {
      this.selectedAssetIds.forEach(selected => {
        this.editableFormElement.append(
          `<input type="hidden" id="${this.hiddenFieldId}_${selected}" name="${this.hiddenFieldKey}" value="${selected}">`
        );
      });
    } else {
      this.editableFormElement.append(
        `<input type="hidden" id="${this.hiddenFieldId}_default" name="${this.hiddenFieldKey}">`
      );
    }
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
    if (!append) {
      this.page = 1;
      this.assetList.html(loadingIcon);
    } else this.assetList.append(loadingIcon);
    DataCycle.disableElement(this.selectButton);
    this.loading = true;
    this.requests.forEach(request => {
      request.abort();
      this.requests = this.requests.filter(r => r != request);
    });
    this.requests.push(
      DataCycle.httpRequest({
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
      }).always((_data, _text, jqXHR) => {
        this.requests = this.requests.filter(r => r != jqXHR);
      })
    );
  }
  updateButtons(_event, data) {
    if (data && data.assets && data.assets.length) {
      if (data.append) this.assets = this.assets.concat(data.assets);
      else this.assets = data.assets;
    }

    if (data !== undefined) {
      if (data.selected && data.selected.length && data.total != 0) {
        DataCycle.enableElement(this.selectButton);
        this.selectButton.data('value', data.selected[0]);
      }

      if (data.total !== undefined) this.total = data.total;
      if (data.page !== undefined) this.page = data.page + 1;
      if (data.last_asset_type !== undefined) this.lastAssetType = data.last_asset_type;
    }
    if (
      this.assetList.children('li').length < this.total &&
      this.assetList.children('li').last().offset().top - this.assetList.offset().top <
        this.assetList.parent().outerHeight()
    ) {
      this.loadAssets();
    } else {
      this.loading = false;
    }
  }
  clickOnAsset(event) {
    if (event.target.closest('a')) return;

    const $selectedItem = $(event.currentTarget);

    if ($selectedItem.hasClass('active')) {
      $selectedItem.removeClass('active');

      if (this.multiSelect) {
        this.selectedAssetIds = this.selectedAssetIds.filter(v => v !== $selectedItem.data('id'));
        if (!this.selectedAssetIds.length) {
          DataCycle.disableElement(this.selectButton);
          this.selectButton.removeData('value');
        }
      } else {
        $selectedItem.siblings('li').removeClass('active');
        this.selectedAssetIds = [];
        DataCycle.disableElement(this.selectButton);
        this.selectButton.removeData('value');
      }
    } else {
      $selectedItem.addClass('active');

      if (this.multiSelect) {
        this.selectedAssetIds.push($selectedItem.data('id'));
      } else {
        $selectedItem.siblings('li').removeClass('active');
        this.selectedAssetIds = [$selectedItem.data('id')];
      }

      DataCycle.enableElement(this.selectButton);
      this.selectButton.data('value', $selectedItem.data('id'));
    }
  }
  selectAssets(event) {
    event.preventDefault();

    if (this.contentUploaderId) {
      $('#' + this.contentUploaderId).trigger('dc:upload:setIds', {
        assets: this.assets.filter(a => this.selectedAssetIds.includes(a.id))
      });
    }
    if (this.editableList.length) this.setSelectedAssets();

    this.reveal.foundation('close');
  }
}

export default AssetSelector;
