// Asset Uploader
var DurationHelpers = require('./../helpers/duration_helpers');
var ObjectHelpers = require('./../helpers/object_helpers');
var RandomNumber = require('./../helpers/random_number_helpers');
var MimeTypes = require('mime-types');

class AssetUploader {
  constructor(reveal) {
    this.reveal = $(reveal);
    this.validations = this.reveal.data('validations');
    this.contentUploader = this.reveal.data('content-uploader');
    this.fileField = this.reveal.find('input[type="file"].upload-file');
    this.uploadForm = this.reveal.find('.content-upload-form');
    this.uploadButton = this.uploadForm.find('.asset-upload-button');
    this.ajaxRequests = [];
    this.autocompleteRequests = {};
    this.files = [];
    this.init();
    console.log(this.validations);
  }
  init() {
    this.reveal.on('open.zf.reveal', this.openReveal.bind(this));
    this.reveal.on('closed.zf.reveal', this.closeReveal.bind(this));
    this.fileField.on('change', this.validateFiles.bind(this));
    this.reveal.on('click', 'a.remove-file', this.removeFile.bind(this));
    this.uploadButton.on('click', this.uploadFile.bind(this));
    this.reveal.on('dc:upload:setFiles', (e, files) => {
      this.validateFiles(e, files.fileList);
    });
    // prevent leaving Site while uploading!
    $(window).on('beforeunload', event => {
      if ($('.file-for-upload.uploading').length) return 'Es gibt noch laufende Uploads!';
    });
  }
  removeFile(event) {
    var target = $(event.currentTarget).parent();
    this.files = this.files.filter(f => f.name != target.data('file'));
    this.updateUploadButton();
    target.remove();
  }
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
  uploadFile(event = null) {
    event && event.preventDefault();
    if (this.files.length > 0) {
      this.uploadForm.find('.upload-file, .asset-upload-label, .asset-upload-button').attr('disabled', true);
      this.files.forEach(element => {
        var fileElement = this.reveal.find('.file-for-upload[data-file="' + element.name + '"]');
        var data = new FormData();
        data.append('asset[file]', element);
        data.append(
          'asset[type]',
          $(fileElement)
            .find('input[type="hidden"].asset-type')
            .val()
        );
        data.append(
          'asset[name]',
          $(fileElement)
            .find('input[type="hidden"].file-title')
            .val()
        );
        console.log(fileElement.find('input[type="hidden"].file-title').val());
        console.log(
          $(fileElement)
            .find('input[type="hidden"].file-title')
            .val()
        );
        console.log(
          $(fileElement)
            .find('input[type="hidden"].asset-type')
            .val()
        );
        var url = this.uploadForm.data('url');
        var type = 'POST';
        var override = $(fileElement).find('.file-override');
        if (override.length) {
          url += '/' + override.data('id');
          type = 'PATCH';
        }
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
                            '% hochgeladen, <span class="eta">' +
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
              if (data.error) {
                this.resetFileField(fileElement);
                this.renderError(fileElement, data.error);
              } else {
                fileElement.removeClass('uploading').addClass('finished');
                fileElement.find('.upload-number').html('hochgeladen, OK');
                fileElement.removeAttr('data-file');
                fileElement.removeData('file');
                this.files = this.files.filter(e => e !== element);
              }
            })
            .fail(data => {
              this.resetFileField(fileElement);
              this.renderError(fileElement, data.statusText);
            })
        );
      });
      this.checkRequests();
    }
  }
  checkRequests() {
    $.when.apply(undefined, this.ajaxRequests).then(
      () => {
        this.uploadForm.find('.upload-file, .asset-upload-label').attr('disabled', false);
        this.ajaxRequests = [];
        this.updateUploadButton();
      },
      () => {
        this.uploadForm.find('.upload-file, .asset-upload-label').attr('disabled', false);
        this.ajaxRequests = [];
        this.updateUploadButton();
      }
    );
  }
  renderError(field, error) {
    field.find('.upload-number').html('Uploadfehler');
    if (field.addClass('error').find('.file-info .error').length)
      field
        .addClass('error')
        .find('.file-info .error')
        .append(error);
    else
      field
        .addClass('error')
        .find('.file-info')
        .append('<span class="error">' + error + '</span>');
  }
  validateFiles(event, files = undefined) {
    if (
      (event.target.files == undefined || event.target.files.length == 0) &&
      (files == undefined || files.length == 0)
    )
      return;
    var new_files = files && files.length ? files : event.target.files;
    for (var i = 0; i < new_files.length; i++) {
      let theFile = new_files[i];

      if (this.files.filter(f => f.name == theFile.name).length == 0) {
        this.files.push(theFile);
        var fileOptions = {
          file: theFile,
          target: this.fileField,
          html: '<i class="fa fa-circle-o-notch fa-spin file-data-loading"></i>'
        };
        this.renderFileField(fileOptions);
      }

      var typeValidations = [];
      var fileExtension = MimeTypes.extension(theFile.type) || theFile.type.split('/').pop();

      for (const key in this.validations) {
        if (this.validations[key].format.indexOf(fileExtension) !== -1) typeValidations.push(this.validations[key]);
      }
      var fileOptions = {
        file: theFile,
        id: RandomNumber.generateRandomId(),
        target: this.fileField,
        validations: typeValidations,
        fileExtension: fileExtension,
        chosenValidation: typeValidations[0]
      };
      this.validateFile(fileOptions);
    }
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
      '<div class="file-info"><span class="file-label">Titel</span><span class="file-name" title="' +
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
    // var appendHtml = '';
    // if (fileOptions.validations.length > 1) {
    //   appendHtml += '<span class="type-selector"><b>Typ: </b>';
    //   fileOptions.validations.forEach((validation, index) => {
    //     appendHtml +=
    //       '<label title="' +
    //       validation.translation_description +
    //       '"><input type="radio" id="' +
    //       fileOptions.file_name +
    //       '_' +
    //       validation.class.replace(/([^A-Za-z0-9[\]{}_.:-])\s?/g, '_') +
    //       '_selector" name="' +
    //       fileOptions.file_name +
    //       '_radio" value="' +
    //       validation.class +
    //       '"' +
    //       (validation.class == fileOptions.chosen_validation.class ? ' checked="checked"' : '') +
    //       '>' +
    //       validation.translation +
    //       (validation.translation_description != '' ? ' <i class="fa fa-info-circle" aria-hidden="true"></i>' : '') +
    //       '</label>';
    //   });
    //   appendHtml += '</span>';
    // } else {
    //   appendHtml +=
    //     '<span class="type-selector"><b>Typ: </b> ' +
    //     (fileOptions.chosenTypeValidation !== undefined
    //       ? fileOptions.chosenTypeValidation.translation
    //       : 'Unbekannt') +
    //     '</span>';
    // }
    // appendHtml +=
    //   '<input type="hidden" class="asset-type" name="asset-type" id="' +
    //   fileOptions.file_name +
    //   '_asset_type" value="' +
    //   (fileOptions.chosenTypeValidation !== undefined ? fileOptions.chosenTypeValidation.class : null) +
    //   '">';
    // appendHtml +=
    //   '<span class="upload-progress"><span class="upload-progress-bar"></span></span>';
    return (
      '<input type="hidden" class="file-title" name="file-title" id="' +
      fileOptions.id +
      '_file_title" value="' +
      fileOptions.file.name +
      '"><input type="hidden" class="asset-type" name="asset-type" id="' +
      fileOptions.id +
      '_asset_type" value="' +
      (fileOptions.chosenTypeValidation && fileOptions.chosenTypeValidation.class) +
      '"><span class="upload-progress"><span class="upload-progress-bar"></span></span>'
    );
  }
  validateFile(fileOptions = {}) {
    if (this.files.filter(f => f.name == fileOptions.file.name).length == 0) {
      this.files.push(fileOptions.file);
    }
    fileOptions.chosenTypeValidation = fileOptions.validations[0];
    fileOptions.mediaHtml = this.fileMediaHTML(fileOptions);
    fileOptions.appendHtml = this.fileAppendHTML(fileOptions);
    fileOptions.fileUrl = URL.createObjectURL(fileOptions.file);
    var validator =
      fileOptions.chosenTypeValidation !== undefined
        ? fileOptions.chosenTypeValidation.class.split('::').pop() + 'Validator'
        : '';
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
    if (fileOptions.chosenTypeValidation !== undefined && !fileOptions.valid.valid) {
      fileOptions.errors = fileOptions.valid.messages.join(', ');
      this.files = this.files.filter(f => f.name != fileOptions.file.name);
    } else if (fileOptions.chosenTypeValidation === undefined) {
      fileOptions.errors = 'Nicht unterstützes Format (' + fileOptions.fileExtension + ')';
      this.files = this.files.filter(f => f.name != fileOptions.file.name);
    }
    this.renderFileField(fileOptions);
    if (this.contentUploader) this.uploadFile();
  }
  validate(fileOptions) {
    var valid = true;
    var messages = [];
    for (var key in fileOptions.chosenTypeValidation) {
      if (typeof this['validate_' + key] == 'function') {
        let validationValue = this['validate_' + key](fileOptions, fileOptions.chosenTypeValidation[key]);
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
    return '<div class="reveal" id="' + fileOptions.id + '_edit_overlay" data-reveal></div>';
  }
  renderFileField(fileOptions) {
    fileOptions.fileField = this.reveal.find('.file-for-upload[data-file="' + fileOptions.file.name + '"]');
    if (!fileOptions.fileField.length) {
      fileOptions.fileField = $(
        '<div class="file-for-upload" data-file="' +
          fileOptions.id +
          '" data-open="' +
          fileOptions.id +
          '_edit_overlay"></div>'
      ).insertBefore(fileOptions.target);
    }
    fileOptions.fileField.html(fileOptions.html);
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
