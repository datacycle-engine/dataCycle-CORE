import loadingIcon from '../templates/loadingIcon';
import ConfirmationModal from './confirmation_modal';

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
    this.activeRequest;
    this.total = 0;
    this.per = 25;
    this.lastAssetType = '';
    this.assets = [];
    this.editableList = $(`#${this.reveal.data('editable-list-id')}`);
    this.editableFormElement = this.editableList.closest('.form-element');
    this.editButton = $(`#${this.reveal.prop('id')}`);
    this.deleteCount = 0;

    this.init();
  }
  init() {
    this.reveal[0].dcAssetSelector = true;
    this.reveal.addClass('dc-asset-selector');
    this.reveal.on('open.zf.reveal', _ => this.loadAssets(false));
    this.assetList.on('click', 'li:not(.locked)', this.clickOnAsset.bind(this));
    this.assetList.on('click', '.asset-destroy', this.destroyAsset.bind(this));
    this.reveal.on('click', '.select-asset-link:not(.disabled)', this.selectAssets.bind(this));
    this.assetList.on('dc:asset_list:changed', this.updateButtons.bind(this));
    this.assetList.parent().on('scroll', this.loadMoreOnScroll.bind(this));
    this.editableList.on('dc:import:data', this.importAsset.bind(this)).addClass('dc-import-data');

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
  importAsset(_event, data) {
    if (data.error)
      return new ConfirmationModal({
        text: data.error
      });

    this.selectedAssetIds = [data.id];
    this.setSelectedAssets();
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
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        this.editableList.find('.loading').remove();

        if (data.assets && data.assets.length) {
          const $html = $(data.html).find('>li, >h4.list-title');

          this.editableList.html($html).trigger('dc:asset_list:changed', {
            assets: data.assets,
            selected: this.selectedAssetIds
          });
        }
      })
      .finally(() => {
        DataCycle.enableElement(this.editButton);
      });
  }
  async destroyAsset(event) {
    event.preventDefault();
    event.stopPropagation();

    const $button = $(event.currentTarget);
    const $asset = $(event.currentTarget).closest('li[data-id]');
    const url = $(event.currentTarget).prop('href');

    DataCycle.disableElement($button);

    new ConfirmationModal({
      text: await I18n.translate('actions.delete_file'),
      confirmationClass: 'alert',
      cancelable: true,
      confirmationCallback: () => {
        this.total--;
        this.deleteCount++;

        DataCycle.httpRequest({
          url: url,
          method: 'DELETE'
        })
          .then(_data => {
            $asset.remove();
          })
          .finally(() => {
            DataCycle.enableElement($button);
          });
      },
      cancelCallback: () => {
        DataCycle.enableElement($button);
      }
    });
  }
  updateHiddenField() {
    if (!this.editableFormElement.length) return;

    this.editableFormElement.children(':hidden').remove();

    if (this.selectedAssetIds && this.selectedAssetIds.length) {
      if (this.editableList.length) this.editableList.addClass('has-items');
      this.selectedAssetIds.forEach(selected => {
        this.editableFormElement.append(
          `<input type="hidden" id="${this.hiddenFieldId}_${selected}" name="${this.hiddenFieldKey}" value="${selected}">`
        );
      });
    } else {
      if (this.editableList.length) this.editableList.removeClass('has-items');

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

    const promise = DataCycle.httpRequest({
      url: '/files/assets',
      method: 'GET',
      data: {
        html_target: this.assetList.prop('id'),
        types: this.assetList.data('asset-types'),
        selected: this.selectedAssetIds,
        page: this.page,
        delete_count: this.deleteCount,
        last_asset_type: this.lastAssetType,
        append: append
      },
      dataType: 'json',
      contentType: 'application/json'
    });

    this.activeRequest = promise;

    promise.then(data => {
      if (this.activeRequest != promise || !data) return;

      this.assetList.find('.loading').remove();

      if (data.assets && data.assets.length) {
        const $html = $(data.html).find('>li, >h4.list-title');

        this.assetList.append($html).trigger('dc:asset_list:changed', {
          assets: data.assets,
          selected: this.selectedAssetIds,
          last_asset_type: data.last_asset_type,
          page: this.page,
          total: data.total,
          append: append
        });
      } else {
        this.assetList.html(data.html).trigger('dc:asset_list:changed', {
          selected: this.selectedAssetIds,
          last_asset_type: '',
          page: 1,
          total: 0,
          append: append
        });
      }
    });
  }
  updateButtons(_event, data) {
    window.requestAnimationFrame(() => {
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
    });
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
