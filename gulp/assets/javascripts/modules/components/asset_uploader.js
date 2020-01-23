// Asset Uploader
var DurationHelpers = require('./../helpers/duration_helpers');
var ObjectHelpers = require('./../helpers/object_helpers');
var RandomNumber = require('./../helpers/random_number_helpers');
var MimeTypes = require('mime-types');

class AssetUploader {
  constructor(reveal) {
    this.reveal = $(reveal);
    this.validation = this.reveal.data('validation');
    this.type = this.reveal.data('type');
    this.remoteOptions = this.reveal.data('remote-options') || {};
    this.contentUploader = this.reveal.data('content-uploader');
    this.fileField = this.reveal.find('input[type="file"].upload-file');
    this.uploadForm = this.reveal.find('.content-upload-form');
    this.uploadButton = this.uploadForm.find('.asset-upload-button');
    this.ajaxRequests = [];
    this.autocompleteRequests = {};
    this.files = [];
    this.init();

    console.log(this.validation);
  }
  init() {
    this.reveal.on('open.zf.reveal', this.openReveal.bind(this));
    this.reveal.on('closed.zf.reveal', this.closeReveal.bind(this));
    this.fileField.on('change', this.validateFiles.bind(this));
    // this.reveal.on('click', 'a.remove-file', this.removeFile.bind(this));
    this.uploadButton.on('click', this.uploadFiles.bind(this));
    this.reveal.on('dc:upload:setFiles', (e, files) => {
      this.validateFiles(e, files.fileList);
    });
    // prevent leaving Site while uploading!
    $(window).on('beforeunload', event => {
      if ($('.file-for-upload.uploading').length) return 'Es gibt noch laufende Uploads!';
    });
  }
  // removeFile(event) {
  //   var target = $(event.currentTarget).parent();
  //   this.files = this.files.filter(f => f.name != target.data('file'));
  //   this.updateUploadButton();
  //   target.remove();
  // }
  openReveal(event) {
    this.reveal.parent('.reveal-overlay').addClass('content-reveal-overlay');
  }
  closeReveal(event) {
    $('.asset-selector-reveal:visible').trigger('open.zf.reveal');
  }
  prepareFileForUpload(element) {
    $(element)
      .removeClass('error finished')
      .addClass('uploading')
      .find('.error')
      .remove();
  }
  uploadFile(file) {
    if (file.uploaded) return;

    this.uploadForm.find('.upload-file, .asset-upload-label, .asset-upload-button').attr('disabled', true);

    var fileElement = $('.file-for-upload[data-id="' + file.id + '"]');
    var data = new FormData();
    data.append('asset[file]', file.file);
    data.append('asset[type]', file.validation.class);
    data.append('asset[name]', file.file.name);
    var url = this.uploadForm.data('url');
    var type = 'POST';
    this.prepareFileForUpload(fileElement);
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
                  fileElement.find('.upload-progress-bar').css('width', (e.loaded / e.total) * 100 + '%');
                  fileElement
                    .find('.upload-number')
                    .html(
                      Math.round((e.loaded / e.total) * 100) +
                        '%, <span class="eta">' +
                        DurationHelpers.seconds_to_human_time(eta) +
                        '</span>'
                    );
                  if (e.loaded == e.total) {
                    fileElement.find('.upload-number').html('wird verarbeitet...');
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
          file.uploaded = true;
          if (data.error) {
            this.resetFileField(fileElement);
            this.renderError(fileElement, data.error);
          } else {
            fileElement.removeClass('uploading').addClass('finished');
            fileElement.find('.upload-number').html('hochgeladen, OK');
            file.asset = data;
            // this.files = this.files.filter(e => e.id !== file.id);
          }
        })
        .fail(data => {
          uploaded = 'failed';
          this.resetFileField(fileElement);
          this.renderError(fileElement, data.statusText);
        })
    );
    this.checkRequests();
  }
  uploadFiles(event) {
    event.preventDefault();

    const uploadableFiles = this.files.filter(f => !f.uploaded);

    console.log(uploadableFiles);

    if (uploadableFiles.length) {
      uploadableFiles.forEach(element => {
        this.uploadFile(element);
      });
    }
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
  renderError(field, error) {
    field
      .addClass('error')
      .find('.upload-number')
      .html('Uploadfehler');
    if (field.find('.file-info .error').length) field.find('.file-info .error').append(error);
    else field.find('.file-info').append('<span class="error">' + error + '</span>');
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
  checkFileAndQueue(file) {
    if (this.files.find(f => f.file.name == file.name)) return;

    let id = RandomNumber.generateRandomId();
    let fileOptions = {
      id: id,
      file: file,
      target: this.fileField,
      html: '<i class="fa fa-circle-o-notch fa-spin file-data-loading"></i>',
      fileExtension: MimeTypes.extension(file.type) || file.type.split('/').pop(),
      validation: this.validation,
      uploaded: false
    };

    this.files.push(fileOptions);
    this.renderInitialFileField(fileOptions);
    this.validateFile(fileOptions);
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
      fileOptions.file.type.split('/').pop() +
      ', ' +
      fileOptions.file.size.file_size(1) +
      additionalFileInfo +
      '</span></div>'
    );
  }
  fileAppendHTML(fileOptions) {
    return '<span class="upload-progress"><span class="upload-progress-bar"></span></span>';
  }
  validateFile(fileOptions = {}) {
    fileOptions.mediaHtml = this.fileMediaHTML(fileOptions);
    fileOptions.appendHtml = this.fileAppendHTML(fileOptions);
    fileOptions.fileUrl = URL.createObjectURL(fileOptions.file);
    var validator = (fileOptions.validation && fileOptions.validation.class.split('::').pop() + 'Validator') || '';
    if (typeof this[validator] == 'function') {
      this[validator](fileOptions);
    } else {
      this.DefaultValidator(fileOptions);
    }
  }
  ImageValidator(fileOptions) {
    var that = this;
    fileOptions.prependHtml = this.fileThumbHtml('<img src="' + fileOptions.fileUrl + '">');
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
    fileOptions.html = fileOptions.prependHtml + fileOptions.mediaHtml + fileOptions.appendHtml;
    fileOptions.valid = this.validate(fileOptions);
    if (fileOptions.validation && !fileOptions.valid.valid) {
      fileOptions.errors = fileOptions.valid.messages.join(', ');
      this.files = this.files.filter(f => f.id != fileOptions.id);
    } else if (!fileOptions.validation) {
      fileOptions.errors = 'Nicht unterstützes Format (' + fileOptions.fileExtension + ')';
      this.files = this.files.filter(f => f.id != fileOptions.id);
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
  renderEditOverlay(fileOptions) {
    this.remoteOptions.search_required = false;
    if (!this.remoteOptions.options)
      this.remoteOptions.options = {
        force_render: true
      };
    this.remoteOptions.search_param = fileOptions.file.name;
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

    $(html).prepend(fileOptions.fileField.clone().removeAttr('data-open'));

    return html;
  }
  renderInitialFileField(fileOptions) {
    fileOptions.fileField = $(
      '<div class="file-for-upload" data-file="' + fileOptions.file.name + '" data-id="' + fileOptions.id + '"></div>'
    ).insertBefore(fileOptions.target);
  }
  renderFileField(fileOptions) {
    fileOptions.fileField = this.reveal.find('.file-for-upload[data-id="' + fileOptions.id + '"]');
    fileOptions.fileField.html(fileOptions.html);
    fileOptions.fileField.attr('data-open', fileOptions.id + '_edit_overlay');
    fileOptions.fileField.append(this.renderEditOverlay(fileOptions)).foundation();
    if (fileOptions.errors) this.renderError(fileOptions.fileField, fileOptions.errors);

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
  resetFileField(field) {
    $(field).removeClass('uploading error');
    $(field)
      .find('.upload-number')
      .html('');
    $(field)
      .find('.upload-progress-bar')
      .css('width', '0');
  }
}

module.exports = AssetUploader;
