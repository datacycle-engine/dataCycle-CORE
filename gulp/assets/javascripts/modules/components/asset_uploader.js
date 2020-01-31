// Asset Uploader
var DurationHelpers = require('./../helpers/duration_helpers');
var ObjectHelpers = require('./../helpers/object_helpers');
var RandomNumber = require('./../helpers/random_number_helpers');
var MimeTypes = require('mime-types');
var ActionCable = require('actioncable');

class AssetUploader {
  constructor(reveal) {
    this.reveal = $(reveal);
    this.validation = this.reveal.data('validation');
    this.type = this.reveal.data('type');
    this.remoteOptions = this.reveal.data('remote-options') || {};
    this.contentUploader = this.reveal.data('content-uploader');
    this.contentUploaderField = $('.content-uploader[data-asset-uploader="' + this.reveal.attr('id') + '"]');
    this.fileField = this.reveal.find('input[type="file"].upload-file');
    this.uploadForm = this.reveal.find('.content-upload-form');
    this.uploadButton = this.uploadForm.find('.asset-upload-button');
    this.createButton = this.uploadForm.find('.asset-create-button');
    this.createButtonHtml = this.createButton.html();
    this.renderedAttributes = this.reveal.data('rendered-attributes') || {};
    this.createDuplicates = this.reveal.data('create-duplicates') || false;
    this.overlayId = this.reveal.attr('id');
    this.assetKey = this.reveal.data('asset_key') || 'asset';
    this.globalFieldValues = [];
    this.ajaxRequests = [];
    this.autocompleteRequests = {};
    this.files = [];
    this.saving = false;
    this.init();
  }
  init() {
    this.reveal.on('open.zf.reveal', this.openReveal.bind(this));
    this.reveal.on('closed.zf.reveal', this.closeReveal.bind(this));
    this.fileField.on('change', this.validateFiles.bind(this));
    this.reveal.on('dc:upload:setFiles', (e, files) => {
      this.validateFiles(e, files.fileList);
    });
    // prevent leaving Site while uploading!
    $(window).on('beforeunload', event => {
      if ($('.file-for-upload.uploading').length) return 'Es gibt noch laufende Uploads!';
    });
    this.reveal.on('dc:upload:setIds', this.importAssetIds.bind(this));
    if (this.contentUploader) {
      this.reveal.on('dc:upload:setFormFields', '.file-for-upload', this.setFormFieldValues.bind(this));
      this.reveal.on('dc:upload:syncWithForm', '.file-for-upload', this.syncWithForm.bind(this));
      this.createButton.on('click', this.createAssets.bind(this));
      this.reveal.on('click', '.file-for-upload .cancel-upload-button', this.removeFileHandler.bind(this));
      this.reveal.on('click', '.file-for-upload .retry-upload-button', this.retryUpload.bind(this));
    }
    this.initActionCable();
  }
  removeFileHandler(event) {
    event.preventDefault();
    event.stopPropagation();
    let target = $(event.currentTarget)
      .closest('.file-for-upload')
      .remove();

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
        // this.updateFileAttributes(file, {
        //   duplicate: f.asset.duplicate_candidates && f.asset.duplicate_candidates.length
        // });
      });
    }
  }
  parseAssetsForImport(assets) {
    if (!assets || !assets.length) return [];

    return assets.map(a => {
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
          duplicate: a.duplicate_candidates && a.duplicate_candidates.length > 0
        }
      };
    });
  }
  retryUpload(event) {
    event.preventDefault();
    event.stopPropagation();
    let target = $(event.currentTarget).closest('.file-for-upload');
    let file = this.files.find(f => f.id == target.data('id'));

    if (file) this.uploadFile(file);
  }
  openReveal(event) {
    this.reveal.parent('.reveal-overlay').addClass('content-reveal-overlay');
  }
  closeReveal(event) {
    $('.asset-selector-reveal:visible').trigger('open.zf.reveal');
  }
  initActionCable() {
    let actionCable = ActionCable.createConsumer();
    let bulkCreateChannel = actionCable.subscriptions.create(
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
              this.reveal.hasClass('in-object-browser') &&
              this.contentUploaderField.length
            ) {
              this.contentUploaderField
                .closest('form.validation-form')
                .trigger('dc:form:setContentIds', { contentIds: data.content_ids.map(i => i.id) });
              this.reveal.foundation('close');
            } else if (!this.files.length && data.redirect_path) {
              window.location.href = data.redirect_path;
            }
          }
        }
      }
    );
  }
  createAssets(event) {
    event.preventDefault();
    this.saving = true;
    if (!this.createButton.prop('disabled')) $.rails.disableFormElement(this.createButton);

    if (!this.files.length) return;

    let formData = this.globalFieldValues;
    formData.push({ name: 'overlay_id', value: this.overlayId });

    this.files.forEach((file, i) => {
      let attributeValues = ObjectHelpers.deepCopy(file.attributeFieldValues);
      attributeValues.push({ name: 'thing[datahash][' + this.assetKey + ']', value: file.asset && file.asset.id });
      attributeValues.push({ name: 'thing[uploader_field_id]', value: file.id });
      attributeValues.forEach(a => {
        a.name = a.name.slice(0, 5) + '[' + i + ']' + a.name.slice(5);
      });

      formData = formData.concat(attributeValues);
    });

    $.ajax({
      url: '/things/bulk_create',
      method: 'POST',
      data: formData,
      dataType: 'json',
      contentType: 'application/x-www-form-urlencoded'
    });
  }
  syncWithForm(event, data = null) {
    event.preventDefault();

    let file = this.files.find(f => f.id == $(event.currentTarget).data('id'));
    let fileAttributes = file.attributeFieldValues;
    if (!fileAttributes) return;
    if (data.key) fileAttributes = fileAttributes.filter(a => a.name.includes(data.key));

    file.fileField.trigger('dc:form:importAttributeValues', {
      locale: data && data.locale,
      attributes: fileAttributes
    });
  }
  setFormFieldValues(event, data = undefined) {
    event.preventDefault();

    if (!data || !data.formData) return;

    let selectedFile = this.files.find(file => file.id == $(event.currentTarget).data('id'));

    this.globalFieldValues = data.formData.filter(elem => elem.name.indexOf('thing') !== 0);
    this.renderSpecificFields(
      data.formData.filter(elem => elem.name.indexOf('thing') === 0),
      data.allFields,
      selectedFile
    );
    this.updateCreateButton();
  }
  renderSpecificFields(fields, all = false, selectedFile = null) {
    let groupedFields = this.groupAttributeValues(fields);
    if (all) {
      this.files.forEach(file => {
        this.updateFileField(file, fields, groupedFields);
      });
      this.updateNeighborForms(fields, selectedFile);
    } else this.updateFileField(selectedFile, fields, groupedFields);
  }
  updateFileField(file, fields, groupedFields) {
    file.attributeFieldValues = ObjectHelpers.deepCopy(fields);
    file.attributeFieldsValidated = true;
    file.fileField
      .add(file.fileFormField)
      .addClass('validated')
      .removeAttr('title');
    groupedFields.forEach((field, i, arr) => {
      this.renderSpecificField(field, file, arr[i - 1]);
    });
  }
  updateNeighborForms(fields, selectedFile) {
    let neighbors = this.files;
    if (selectedFile) neighbors = neighbors.filter(file => file.id != selectedFile.id);

    neighbors.forEach(file => {
      file.fileField.trigger('dc:form:importAttributeValues', { attributes: fields });
    });
  }
  groupAttributeValues(fields) {
    let attributeValues = [];

    fields.forEach(field => {
      if (field.name.includes('[translations]') && !field.name.includes('[translations][de]')) return;

      let foundAttribute = attributeValues.find(f => f.name == field.name);
      if (foundAttribute) {
        if (!field.value || !field.value.length) return;
        if (Number.isNaN(foundAttribute.count)) foundAttribute.count = 0;

        foundAttribute.count++;
        foundAttribute.value = this.renderAttributeHtml(
          foundAttribute.name,
          '<span class="count">' + foundAttribute.count + '</span>',
          'text-center'
        );
      } else if (
        this.renderedAttributes[field.name.getKey()] &&
        ['linked', 'embedded', 'classification'].includes(this.renderedAttributes[field.name.getKey()].type)
      ) {
        let count = field.value && field.value.length ? 1 : 0;
        attributeValues.push({
          name: field.name,
          count: count,
          type: 'count',
          value: this.renderAttributeHtml(field.name, '<span class="count">' + count + '</span>', 'text-center')
        });
      } else
        attributeValues.push({
          name: field.name,
          value: this.renderAttributeHtml(field.name, field.value)
        });
    });

    return attributeValues;
  }
  renderAttributeHtml(name, value, classes = '') {
    let label =
      (this.renderedAttributes[name.getKey()] && this.renderedAttributes[name.getKey()].label) || name.getKey();

    if (
      this.renderedAttributes[name.getKey()] &&
      this.renderedAttributes[name.getKey()].type == 'datetime' &&
      value &&
      value.length
    ) {
      value = new Date(value).toLocaleDateString();
    }

    return (
      '<span class="file-label" title="' +
      label +
      '">' +
      label +
      '</span><span class="file-attribute-value ' +
      classes +
      '" title="' +
      $('<span>' + value + '</span>').text() +
      '">' +
      value +
      '</span>'
    );
  }
  renderSpecificField(field, asset, previousField = null) {
    if (asset.fileField.find('.asset-attribute[data-name="' + field.name + '"]').length)
      asset.fileField.find('.asset-attribute[data-name="' + field.name + '"]').html(field.value);
    else if (previousField)
      asset.fileField
        .find('.new-asset-attributes .asset-attribute[data-name="' + previousField.name + '"]')
        .after(this.attributeValueHtml(field));
    else asset.fileField.find('.new-asset-attributes').append(this.attributeValueHtml(field));
  }
  attributeValueHtml(field) {
    return (
      '<div class="asset-attribute ' +
      (this.renderedAttributes[field.name.getKey()] && this.renderedAttributes[field.name.getKey()].type) +
      '" data-name="' +
      field.name +
      '">' +
      field.value +
      '</div>'
    );
  }
  prepareFileForUpload(file) {
    file.fileField
      .add(file.fileFormField)
      .removeClass('error finished')
      .addClass('uploading')
      .find('.error')
      .remove();
  }
  uploadFile(file) {
    if (file.uploaded) {
      this.updateFileAttributes(file, file.dataImported || {});
      return;
    }

    this.uploadForm.find('.upload-file, .asset-upload-label, .asset-upload-button').attr('disabled', true);

    var data = new FormData();
    data.append('asset[file]', file.file);
    data.append('asset[type]', file.validation.class);
    data.append('asset[name]', file.file.name);
    var url = this.uploadForm.data('url');
    var type = 'POST';
    this.prepareFileForUpload(file);
    var startTime = new Date().getTime();
    this.ajaxRequests.push(
      $.ajax({
        url: url,
        type: type,
        enctype: 'multipart/form-data',
        data: data,
        dataType: 'json',
        processData: false,
        contentType: false,
        cache: false,
        xhr: function() {
          var myXhr = $.ajaxSettings.xhr();
          if (myXhr.upload) {
            myXhr.upload.addEventListener(
              'progress',
              function(e) {
                if (e.lengthComputable) {
                  var elapsedtime = (new Date().getTime() - startTime) / 1000;
                  var eta = Math.round((e.total / e.loaded) * elapsedtime - elapsedtime);
                  file.fileField
                    .add(file.fileFormField)
                    .find('.upload-progress-bar')
                    .css('width', (e.loaded / e.total) * 100 + '%');
                  file.fileField
                    .add(file.fileFormField)
                    .find('.upload-number')
                    .html(
                      Math.round((e.loaded / e.total) * 100) +
                        '%, <span class="eta">' +
                        DurationHelpers.seconds_to_human_time(eta) +
                        '</span>'
                    );
                  if (e.loaded == e.total) {
                    file.fileField
                      .add(file.fileFormField)
                      .find('.upload-number')
                      .html('wird verarbeitet...');
                  }
                }
              },
              false
            );
          }
          return myXhr;
        }
      })
        .done(data => {
          this.updateFileAttributes(file, data);
        })
        .fail(data => {
          file.retryUpload = true;
          this.resetFileField(file);
          this.renderError(file, data.statusText);
        })
        .always(data => {
          this.updateOverlayButtons(file);
        })
    );
    this.checkRequests();
  }
  updateFileAttributes(file, data) {
    file.retryUpload = false;
    let error = null;

    file.fileField
      .add(file.fileFormField)
      .find('.upload-progress-bar')
      .css('width', '100%');

    if (data.error) {
      this.resetFileField(file);
      this.renderError(file, data.error);
      error = data.error;
    } else if (!this.createDuplicates && data.duplicate) {
      this.resetFileField(file);
      this.renderError(file, 'Duplikat gefunden!');
      error = 'Duplikat gefunden!';
    } else {
      if (data.duplicate) this.renderErrorHtml(file, 'notice', 'Duplikat gefunden!');

      file.uploaded = true;
      file.fileField
        .add(file.fileFormField)
        .removeClass('uploading')
        .addClass('finished')
        .find('.upload-number')
        .html('hochgeladen, OK');
      file.asset = Object.assign({}, file.asset, data);
    }
    this.updateCreateButton(error);
  }
  reset(ids = null) {
    if (ids) {
      $(this.files.filter(f => ids.includes(f.id)).forEach(f => f.fileField.remove()));
      this.files = this.files.filter(f => !ids.includes(f.id));
      this.files.forEach(file => {
        this.renderError(file, 'Fehler beim Speichern des Inhalts!');
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
    this.uploadForm.find('.upload-file, .asset-upload-label').attr('disabled', false);
    this.ajaxRequests = [];
    this.updateUploadButton();
  }
  checkRequests() {
    $.when.apply(undefined, this.ajaxRequests).then(
      () => this.enableButtons(),
      () => this.enableButtons()
    );
  }
  renderErrorHtml(file, cssClass, message) {
    let fileInfoFields = file.fileField.add(file.fileFormField).find('.file-info');
    if (fileInfoFields.find('.' + cssClass).length) fileInfoFields.find('.' + cssClass).text(message);
    else fileInfoFields.append('<span class="' + cssClass + '">' + message + '</span>');
  }
  renderError(file, error) {
    file.fileField
      .add(file.fileFormField)
      .addClass('error')
      .find('.upload-number')
      .html('Uploadfehler');

    this.renderErrorHtml(file, 'error', error);
    this.updateOverlayButtons(file);
  }
  updateOverlayButtons(file) {
    if (file.retryUpload) file.fileField.addClass('retry');
    else file.fileField.removeClass('retry');
  }
  validateFiles(event, files = undefined) {
    if (
      (event.target.files == undefined || event.target.files.length == 0) &&
      (files == undefined || files.length == 0)
    )
      return;
    var newFiles = files && files.length ? files : event.target.files;

    for (var i = 0; i < newFiles.length; i++) {
      this.checkFileAndQueue(newFiles[i]);
    }
  }
  checkFileAndQueue(file, fileOptions = {}) {
    if (this.files.find(f => f.file.name == file.name)) return;

    let id = RandomNumber.generateRandomId();
    fileOptions = Object.assign(
      {
        id: id,
        file: file,
        target: this.fileField,
        html: '<i class="fa fa-circle-o-notch fa-spin file-data-loading"></i>',
        fileExtension: this.getFileExtension(file),
        validation: this.validation,
        uploaded: false
      },
      fileOptions
    );

    this.files.push(fileOptions);
    this.renderInitialFileField(fileOptions);
    this.validateFile(fileOptions);
    this.updateCreateButton('Metadaten müssen für jede Datei ausgefüllt werden!');

    return fileOptions;
  }
  getFileExtension(file) {
    let mimeType = MimeTypes.lookup(file.name) || file.type;
    let nameExtension = file.name.split('.').pop();

    if (MimeTypes.extensions[mimeType] && MimeTypes.extensions[mimeType].includes(nameExtension)) return nameExtension;

    return MimeTypes.extension(mimeType) || file.type.split('/').pop();
  }
  fileThumbHtml(thumbHtml) {
    return (
      '<div class="file-thumb">' +
      thumbHtml +
      '<span class="upload-number-container"><span class="upload-number"></span></span></div>'
    );
  }
  fileMediaHTML(fileOptions, additionalFileInfo = '') {
    return (
      '<div class="file-info"><span class="file-label">Datei</span><span class="file-name" title="' +
      (fileOptions.file && fileOptions.file.name) +
      '">' +
      (fileOptions.file && fileOptions.file.name) +
      '</span><span class="file-details">' +
      fileOptions.fileExtension +
      ', ' +
      fileOptions.file.size.file_size(1) +
      additionalFileInfo +
      '</span></div>'
    );
  }
  fileAppendHTML(fileOptions) {
    return '<div class="upload-progress"><span class="upload-progress-bar"></span></div><div class="button-overlay"><button class="button edit-upload-button" title="Inhalt bearbeiten"><i class="fa fa-pencil" aria-hidden="true"></i></button><button class="button retry-upload-button" title="Erneut hochladen"><i class="fa fa-refresh" aria-hidden="true"></i></button><button class="button cancel-upload-button alert" title="Datei entfernen"><i class="fa fa-minus" aria-hidden="true"></i></button></div>';
  }
  validateFile(fileOptions = {}) {
    fileOptions.mediaHtml = this.fileMediaHTML(fileOptions);
    fileOptions.appendHtml = this.fileAppendHTML(fileOptions);
    if (!fileOptions.fileUrl) fileOptions.fileUrl = URL.createObjectURL(fileOptions.file);
    var validator = (fileOptions.validation && fileOptions.validation.class.split('::').pop() + 'Validator') || '';
    if (typeof this[validator] == 'function') {
      this[validator](fileOptions);
    } else {
      this.DefaultValidator(fileOptions);
    }
  }
  ImageValidator(fileOptions) {
    var that = this;
    fileOptions.prependHtml = this.fileThumbHtml(
      '<object data="' +
        fileOptions.fileUrl +
        '" type="' +
        fileOptions.file.type +
        '"><i class="fa fa-picture-o" aria-hidden="true"></i></object>'
    );
    var theImage = new Image();
    theImage.onload = function() {
      fileOptions.mediaHtml = that.fileMediaHTML(
        fileOptions,
        ', ' + theImage.naturalWidth + 'x' + theImage.naturalHeight + 'px'
      );
      fileOptions.validationOptions = {
        width: theImage.naturalWidth,
        height: theImage.naturalHeight
      };
      that.validateAndRender(fileOptions);
    };
    theImage.onerror = function() {
      that.validateAndRender(fileOptions);
    };
    theImage.src = fileOptions.fileUrl;
  }
  VideoValidator(fileOptions) {
    var that = this;
    fileOptions.prependHtml = this.fileThumbHtml('<i class="fa fa-video-camera" aria-hidden="true"></i>');
    var theVideo = document.createElement('video');
    theVideo.onloadedmetadata = function() {
      window.URL.revokeObjectURL(this.src);
      fileOptions.mediaHtml = that.fileMediaHTML(
        fileOptions,
        ', ' +
          theVideo.videoWidth +
          'x' +
          theVideo.videoHeight +
          'px, ' +
          DurationHelpers.seconds_to_human_time(theVideo.duration)
      );
      fileOptions.validationOptions = {
        width: theVideo.videoWidth,
        height: theVideo.videoHeight
      };
      that.validateAndRender(fileOptions);
    };
    theVideo.onerror = function() {
      that.validateAndRender(fileOptions);
    };
    theVideo.setAttribute('src', fileOptions.fileUrl);
  }
  AudioValidator(fileOptions) {
    fileOptions.prependHtml = this.fileThumbHtml('<i class="fa fa-file-audio-o" aria-hidden="true"></i>');
    this.validateAndRender(fileOptions);
  }
  PdfValidator(fileOptions) {
    fileOptions.prependHtml = this.fileThumbHtml('<i class="fa fa-file-pdf-o" aria-hidden="true"></i>');
    this.validateAndRender(fileOptions);
  }
  TextFileValidator(fileOptions) {
    fileOptions.prependHtml = this.fileThumbHtml('<i class="fa fa-file-text-o" aria-hidden="true"></i>');
    this.validateAndRender(fileOptions);
  }
  DefaultValidator(fileOptions) {
    fileOptions.prependHtml = this.fileThumbHtml('<i class="fa fa-file-o" aria-hidden="true"></i>');
    this.validateAndRender(fileOptions);
  }
  validateAndRender(fileOptions) {
    fileOptions.html =
      '<div class="new-asset-attributes">' +
      fileOptions.prependHtml +
      fileOptions.mediaHtml +
      '</div>' +
      fileOptions.appendHtml;
    fileOptions.valid = this.validate(fileOptions);
    if (fileOptions.validation && !fileOptions.valid.valid) {
      fileOptions.errors = fileOptions.valid.messages.join(', ');
    } else if (!fileOptions.validation) {
      fileOptions.errors = 'Nicht unterstützes Format (' + fileOptions.fileExtension + ')';
    }
    this.renderFileField(fileOptions);
    if (this.contentUploader && !fileOptions.errors) this.uploadFile(fileOptions);
  }
  validate(fileOptions) {
    var valid = true;
    var messages = [];
    for (var key in fileOptions.validation) {
      if (typeof this['validate_' + key] == 'function') {
        let validationValue = this['validate_' + key](fileOptions, fileOptions.validation[key]);
        valid &= validationValue.valid;
        if (validationValue.message !== undefined) messages.push(validationValue.message);
      }
    }
    return {
      valid: valid,
      messages: messages
    };
  }
  updateUploadButton() {
    if (this.files.length > 0 && this.ajaxRequests.length == 0) this.uploadButton.attr('disabled', false);
    else this.uploadButton.attr('disabled', true);
  }
  updateCreateButton(error = null) {
    if (this.files.length && !this.files.filter(f => !f.attributeFieldsValidated || !f.uploaded).length)
      $.rails.enableFormElement(this.createButton);
    else {
      $.rails.disableFormElement(this.createButton);
      if (!error) error = 'Fehlende Metadaten!';
    }

    if (error) this.createButton.attr('title', 'Fehler: ' + error);
    else this.createButton.removeAttr('title');
  }
  renderEditOverlay(fileOptions) {
    this.remoteOptions.search_required = false;
    if (!this.remoteOptions.options)
      this.remoteOptions.options = {
        force_render: true
      };
    this.remoteOptions.search_param = fileOptions.file.name;
    this.remoteOptions.content_uploader = true;
    this.remoteOptions.asset_class = fileOptions.validation.class;
    this.remoteOptions.options.prefix = fileOptions.id;
    this.remoteOptions.options.render_attributes = true;

    let html = $(
      '<div class="reveal new-content-reveal" id="' +
        fileOptions.id +
        '_edit_overlay" data-reveal><button class="close-button" data-close aria-label="Close modal" type="button"><span aria-hidden="true">&times;</span></button><div class="new-content-form remote-render" id="' +
        fileOptions.id +
        '_new_form" data-remote-path="data_cycle_core/contents/new/shared/new_form"></div></div>'
    );

    $(html)
      .find('.new-content-form')
      .attr('data-remote-options', JSON.stringify(this.remoteOptions));

    fileOptions.fileFormField = $(fileOptions.fileField.clone().removeAttr('data-open')).prependTo(html);
    fileOptions.fileField
      .find('.button-overlay .edit-upload-button')
      .attr('data-open', fileOptions.id + '_edit_overlay');

    return html;
  }
  renderInitialFileField(fileOptions) {
    fileOptions.fileField = $(
      '<div class="file-for-upload" title="Metadaten müssen ausgefüllt werden!" data-file="' +
        fileOptions.file.name +
        '" data-id="' +
        fileOptions.id +
        '"></div>'
    ).insertBefore(fileOptions.target);
  }
  renderFileField(fileOptions) {
    fileOptions.fileField = this.reveal.find('.file-for-upload[data-id="' + fileOptions.id + '"]');
    fileOptions.fileField.html(fileOptions.html);
    fileOptions.fileField.append(this.renderEditOverlay(fileOptions)).foundation();
    if (fileOptions.errors) this.renderError(fileOptions, fileOptions.errors);
    else this.updateOverlayButtons(fileOptions);

    this.updateUploadButton();
  }
  validate_file_size(fileOptions, validations) {
    var messages = '';
    var valid = true;
    if (validations.max !== undefined && fileOptions.file.size > validations.max) {
      valid = false;
      messages += 'Datei zu groß (maximal ' + validations.max.file_size(0) + ')';
    }
    if (validations.min !== undefined && fileOptions.file.size < validations.min) {
      valid = false;
      messages += 'Datei zu klein (mindestens ' + validations.min.file_size(0) + ')';
    }
    return {
      valid: valid,
      message: valid ? undefined : messages
    };
  }
  validate_format(fileOptions, validations) {
    validations.forEach(format => {
      let mimeType = MimeTypes.lookup(format);
      if (mimeType) validations = validations.concat(MimeTypes.extensions[mimeType]);
    });

    var valid = validations.indexOf(fileOptions.fileExtension) !== -1;

    return {
      valid: valid,
      message: valid ? undefined : 'Nicht unterstützes Format (' + fileOptions.fileExtension + ')'
    };
  }
  validate_dimensions(fileOptions, validations) {
    if (fileOptions.validationOptions !== undefined) {
      var additional = ObjectHelpers.reject(validations, ['landscape', 'portrait', 'exclude']);
      if (
        ObjectHelpers.get(['exclude', 'format'], validations) !== null &&
        ObjectHelpers.get(['exclude', 'format'], validations).indexOf(fileOptions.fileExtension) !== -1
      ) {
        return {
          valid: true,
          message: undefined
        };
      }
      for (var key in additional) {
        if (
          additional[key].max !== undefined &&
          ((additional[key].max.height !== undefined &&
            fileOptions.validationOptions.height <= additional[key].max.height) ||
            (additional[key].max.width !== undefined &&
              fileOptions.validationOptions.width <= additional[key].max.width))
        ) {
          return {
            valid: true,
            message: undefined
          };
        }
        if (
          additional[key].min !== undefined &&
          ((additional[key].min.height !== undefined &&
            fileOptions.validationOptions.height >= additional[key].min.height) ||
            (additional[key].min.width !== undefined &&
              fileOptions.validationOptions.width >= additional[key].min.width))
        ) {
          return {
            valid: true,
            message: undefined
          };
        }
      }
      if (
        (fileOptions.validationOptions.width >= fileOptions.validationOptions.height &&
          ((ObjectHelpers.get(['landscape', 'min', 'width'], validations) !== null &&
            fileOptions.validationOptions.width < validations.landscape.min.width) ||
            (ObjectHelpers.get(['landscape', 'min', 'height'], validations) !== null &&
              fileOptions.validationOptions.height < validations.landscape.min.height))) ||
        (fileOptions.validationOptions.width < fileOptions.validationOptions.height &&
          ((ObjectHelpers.get(['portrait', 'min', 'width'], validations) !== null &&
            fileOptions.validationOptions.width < validations.portrait.min.width) ||
            (ObjectHelpers.get(['portrait', 'min', 'height'], validations) !== null &&
              fileOptions.validationOptions.height < validations.portrait.min.height)))
      ) {
        var message =
          'Bild zu klein (' +
          fileOptions.validationOptions.width +
          'x' +
          fileOptions.validationOptions.height +
          '), sollte' +
          (ObjectHelpers.get(['landscape', 'min'], validations) !== null
            ? ' für Querformat mind. ' +
              ObjectHelpers.get(['landscape', 'min', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['landscape', 'min', 'height'], validations)
            : '') +
          (ObjectHelpers.get(['landscape', 'min'], validations) !== null &&
          ObjectHelpers.get(['portrait', 'min'], validations) !== null
            ? ','
            : '') +
          (ObjectHelpers.get(['portrait', 'min'], validations) !== null
            ? ' für Hochformat mind. ' +
              ObjectHelpers.get(['portrait', 'min', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['portrait', 'min', 'height'], validations)
            : '') +
          ' sein.';
        return {
          valid: false,
          message: message
        };
      }
      if (
        (fileOptions.validationOptions.width >= fileOptions.validationOptions.height &&
          ((ObjectHelpers.get(['landscape', 'max', 'width'], validations) !== null &&
            fileOptions.validationOptions.width > validations.landscape.max.width) ||
            (ObjectHelpers.get(['landscape', 'max', 'height'], validations) !== null &&
              fileOptions.validationOptions.height > validations.landscape.max.height))) ||
        (fileOptions.validationOptions.width < fileOptions.validationOptions.height &&
          ((ObjectHelpers.get(['portrait', 'max', 'width'], validations) !== null &&
            fileOptions.validationOptions.width > validations.portrait.max.width) ||
            (ObjectHelpers.get(['portrait', 'max', 'height'], validations) !== null &&
              fileOptions.validationOptions.height > validations.portrait.max.height)))
      ) {
        var message =
          'Bild zu groß (' +
          fileOptions.validationOptions.width +
          'x' +
          fileOptions.validationOptions.height +
          '), sollte' +
          (ObjectHelpers.get(['landscape', 'max'], validations) !== null
            ? ' für Querformat max. ' +
              ObjectHelpers.get(['landscape', 'max', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['landscape', 'max', 'height'], validations)
            : '') +
          (ObjectHelpers.get(['landscape', 'max'], validations) !== null &&
          ObjectHelpers.get(['portrait', 'max'], validations) !== null
            ? ','
            : '') +
          (ObjectHelpers.get(['portrait', 'max'], validations) !== null
            ? ' für Hochformat max. ' +
              ObjectHelpers.get(['portrait', 'max', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['portrait', 'max', 'height'], validations)
            : '') +
          ' sein.';
        return {
          valid: false,
          message: message
        };
      }
    }
    return {
      valid: true,
      message: undefined
    };
  }
  resetFileField(file) {
    file.fileField.add(file.fileFormField).removeClass('uploading error');
    file.fileField
      .add(file.fileFormField)
      .find('.upload-number')
      .html('');
    file.fileField
      .add(file.fileFormField)
      .find('.upload-progress-bar')
      .css('width', '0');
  }
}

module.exports = AssetUploader;
