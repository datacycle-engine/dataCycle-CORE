import cloneDeep from 'lodash/cloneDeep';
import AssetFile from './asset_uploader/asset_file';

class AssetUploader {
  constructor(reveal) {
    this.reveal = $(reveal);
    this.validation = this.reveal.data('validation');
    this.type = this.reveal.data('type');
    this.templateName = this.reveal.data('template');
    this.remoteOptions = this.reveal.data('remote-options') || {};
    this.contentUploader = this.reveal.data('content-uploader');
    this.contentUploaderField = $('.content-uploader[data-asset-uploader="' + this.reveal.attr('id') + '"]');
    this.fileField = this.reveal.find('input[type="file"].upload-file');
    this.uploadForm = this.reveal.find('.content-upload-form');
    this.createButton = this.uploadForm.find('.content-create-button');
    this.assetReloadButton = this.uploadForm.find('.asset-reload-button');
    this.renderedAttributes = this.reveal.data('rendered-attributes') || {};
    this.formAttributes = this.reveal.data('form-attributes') || {};
    this.showNewForm = Object.keys(this.formAttributes).length > 0;
    this.createDuplicates = this.reveal.data('create-duplicates') || false;
    this.locale = this.reveal.data('locale') || 'de';
    this.overlayId = this.reveal.attr('id');
    this.assetKey = this.reveal.data('asset-key') || 'asset';
    this.globalFieldValues = [];
    this.ajaxRequests = [];
    this.autocompleteRequests = {};
    this.bulkCreateChannel;
    this.files = [];
    this.saving = false;
    this.createAssetsRequest;
    this.eventHandlers = {
      pageLeave: this.pageLeaveHandler.bind(this)
    };

    this.init();
  }
  init() {
    this.reveal.addClass('initialized');
    this.reveal.on('open.zf.reveal', this.openReveal.bind(this));
    this.reveal.on('closed.zf.reveal', this.closeReveal.bind(this));
    this.fileField.on('change', this.validateFiles.bind(this));
    this.reveal.on('dc:upload:setFiles', (e, files) => {
      this.validateFiles(e, files.fileList);
    });
    this.reveal.on('dc:upload:setIds', this.importAssetIds.bind(this));
    this.reveal.on(
      'click',
      '.file-for-upload:not(.uploading) .cancel-upload-button',
      this.removeFileHandler.bind(this)
    );

    if (this.contentUploader) this.createButton.on('click', this.createAssets.bind(this));

    this.initActionCable();
  }
  pageLeaveHandler(e) {
    e.preventDefault();
    return (e.returnValue = '');
  }
  removeFileHandler(event) {
    event.preventDefault();
    event.stopPropagation();

    let target = $(event.currentTarget).closest('.file-for-upload').remove();

    this.files = this.files.filter(f => f.id != target.data('id'));
    this.updateCreateButton();
  }
  importAssetIds(event, data) {
    event.preventDefault();
    event.stopPropagation();

    this.reveal.foundation('open');

    let parsedAssets = this.parseAssetsForImport(data.assets);

    if (parsedAssets.length) {
      parsedAssets.forEach(f => {
        this.checkFileAndQueue(f.file, f);
      });
    }
  }
  parseAssetsForImport(assets) {
    if (!assets || !assets.length) return [];

    return assets.map(a => {
      let duplicateCandidates = a.duplicate_candidates;

      if (duplicateCandidates && duplicateCandidates.length)
        duplicateCandidates = duplicateCandidates.map(d => {
          return {
            id: d.id,
            thumbnail_url: d.metadata && d.metadata.thumbnail_url
          };
        });

      return {
        uploaded: true,
        file: {
          type: a.content_type,
          name: a.name,
          size: a.file_size
        },
        fileUrl: a.file.url,
        asset: a,
        dataImported: {
          duplicateCandidates: duplicateCandidates
        }
      };
    });
  }
  openReveal(_event) {
    $(window).on('beforeunload', this.eventHandlers.pageLeave);
    this.reveal.parent('.reveal-overlay').addClass('content-reveal-overlay');
  }
  closeReveal(_event) {
    $(window).off('beforeunload', this.eventHandlers.pageLeave);
    this.contentUploaderField.trigger('dc:upload:filesChanged');
    $('.asset-selector-reveal:visible').trigger('open.zf.reveal');
  }
  initActionCable() {
    this.bulkCreateChannel = window.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::BulkCreateChannel',
        overlay_id: this.overlayId
      },
      {
        received: data => {
          if (data.progress && this.saving) {
            let progress = Math.round((data.progress * 100) / data.items);
            this.createButton.find('.progress-value').text(progress + '%');
            this.createButton.find('.progress-bar > .progress-filled').css('width', progress + '%');
          } else if (data.content_ids) {
            this.reset(data.content_ids.map(i => i.field_id));

            if (
              !this.files.length &&
              data.created &&
              this.contentUploaderField.closest('.reveal.new-content-reveal').hasClass('in-object-browser') &&
              this.contentUploaderField.length
            ) {
              this.contentUploaderField
                .closest('form.validation-form')
                .trigger('dc:form:setContentIds', { contentIds: data.content_ids.map(i => i.id) });
              this.reveal.foundation('close');
            } else if (!this.files.length && data.redirect_path) {
              let redirect_path = data.redirect_path;
              if (data && data.flash) {
                Object.keys(data.flash).forEach((item, index) => {
                  redirect_path += `${index == 0 ? '?' : '&'}flash[${item}]=${encodeURI(data.flash[item])}`;
                });
              }
              window.location.href = redirect_path;
            }
          }
        }
      }
    );
  }
  createAssets(event) {
    event.preventDefault();
    this.saving = true;

    if (this.contentUploader && !this.createButton.prop('disabled')) DataCycle.disableElement(this.createButton);
    if (!this.files.length) return;

    let formData = this.globalFieldValues;

    formData.push({ name: 'overlay_id', value: this.overlayId });

    if (!formData.find(f => f.name.includes('template')) && this.templateName && this.templateName.length)
      formData.push({ name: 'template', value: this.templateName });

    this.files.forEach((file, i) => {
      file.fileField.addClass('creating');

      const attributeValues = cloneDeep(file.attributeFieldValues) || [];
      attributeValues.push({ name: 'thing[datahash][' + this.assetKey + ']', value: file.assetId() });
      attributeValues.push({ name: 'thing[uploader_field_id]', value: file.id });
      attributeValues.forEach(a => {
        a.name = a.name.slice(0, 5) + '[' + i + ']' + a.name.slice(5);
      });

      formData = formData.concat(attributeValues);
    });

    $(window).off('beforeunload', this.eventHandlers.pageLeave);

    return DataCycle.httpRequest({
      url: '/things/bulk_create',
      method: 'POST',
      data: formData,
      dataType: 'json',
      contentType: 'application/x-www-form-urlencoded'
    }).catch(e => {
      if (e.status >= 400) console.error(e.statusText);
    });
  }
  reset(ids = null) {
    if (ids) {
      $(this.files.filter(f => ids.includes(f.id)).forEach(f => f.fileField.remove()));
      this.files = this.files.filter(f => !ids.includes(f.id));
      this.files.forEach(async file => {
        file._renderError(await I18n.translate('frontend.upload.error_saving_content'));
      });
    } else {
      this.uploadForm.find('.file-for-upload').remove();
      this.files = [];
    }

    this.saving = false;
    this.createButton.find('.progress-value').html('');
    this.createButton.find('.progress-bar > .progress-filled').css('width', '0%');
    this.updateCreateButton();
  }
  enableButtons() {
    this.uploadForm.find('.upload-file').attr('disabled', false);
    this.ajaxRequests = [];
  }
  checkRequests() {
    $.when.apply(undefined, this.ajaxRequests).then(
      () => this.enableButtons(),
      () => this.enableButtons()
    );
  }
  validateFiles(event, files = undefined) {
    if (
      (event.target.files == undefined || event.target.files.length == 0) &&
      (files == undefined || files.length == 0)
    )
      return;

    const newFiles = files && files.length ? files : event.target.files;

    for (const file of newFiles) {
      this.checkFileAndQueue(file);
    }
  }
  async checkFileAndQueue(file, fileOptions = {}) {
    if (this.files.find(f => f.file.name == file.name)) return;

    fileOptions = Object.assign({ file: file }, fileOptions);

    const assetFile = new AssetFile(this, fileOptions);
    await assetFile.renderFile();

    this.files.push(assetFile);
    this.updateCreateButton(await I18n.translate('frontend.upload.metadata_warning.many'));
  }
  async updateCreateButton(error = null) {
    if (this.files.length && !this.files.filter(f => !f.attributeFieldsValidated || !f.uploaded).length) {
      DataCycle.enableElement(this.createButton);
    } else {
      DataCycle.disableElement(this.createButton);
      if (!error) error = await I18n.translate('frontend.upload.missing_metadata');
    }

    if (error) this.createButton.attr('data-dc-tooltip', `${await I18n.translate('frontend.upload.error')}: ${error}`);
    else this.createButton.removeAttr('data-dc-tooltip');
  }
}

export default AssetUploader;
