// Asset Uploader
var duration_helpers = require('./../helpers/duration_helpers');
var object_helpers = require('./../helpers/object_helpers');

var AssetUploader = function(reveal) {
  this.reveal = $(reveal);
  this.validations = this.reveal.data('validations');
  this.file_field = this.reveal.find('input[type="file"].upload-file');
  this.upload_form = this.reveal.find('#content-upload-form');
  this.ajax_requests = [];
  this.files = [];

  this.init();
};

AssetUploader.prototype.init = function() {
  this.reveal.on('open.zf.reveal', this.openReveal.bind(this));
  this.reveal.on('closed.zf.reveal', this.closeReveal.bind(this));
  this.file_field.on('change', this.validateFiles.bind(this));
  this.reveal.on('click', 'a.remove-file', this.removeFile.bind(this));
  this.upload_form.on('submit', this.uploadFile.bind(this));

  // prevent leaving Site while uploading!
  $(window).on('beforeunload', event => {
    if ($('.file-for-upload.uploading').length)
      return 'Es gibt noch laufende Uploads!';
  });
};

AssetUploader.prototype.removeFile = function(event) {
  var target = $(event.currentTarget).parent();
  this.files = this.files.filter(f => f.name != target.data('file'));
  target.remove();
};

AssetUploader.prototype.openReveal = function(event) {
  this.reveal.parent('.reveal-overlay').addClass('content-reveal-overlay');
};

AssetUploader.prototype.closeReveal = function(event) {
  $('.asset-selector-reveal:visible').trigger('open.zf.reveal');
};

AssetUploader.prototype.prepareFileForUpload = function(element) {
  $(element)
    .removeClass('error finished')
    .addClass('uploading')
    .find('.error')
    .remove();

  $(element)
    .find('.type-selector')
    .hide();
};

AssetUploader.prototype.uploadFile = function(event) {
  event.preventDefault();

  if (this.files.length > 0) {
    this.upload_form.find('.button, #files').attr('disabled', true);

    this.files.forEach(element => {
      var file_element = this.reveal.find(
        '.file-for-upload[data-file="' + element.name + '"]'
      );
      this.prepareFileForUpload(file_element);

      var data = new FormData();
      data.append('asset[file]', element);
      data.append(
        'asset[type]',
        $(file_element)
          .find('input[type="hidden"].asset-type')
          .val()
      );
      data.append(
        'asset[name]',
        $(file_element)
          .find('input[type="text"].file-title')
          .val()
      );

      var startTime = new Date().getTime();

      this.ajax_requests.push(
        $.ajax({
          url: $(event.currentTarget).attr('action'),
          type: 'POST',
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
                    var eta = Math.round(
                      (e.total / e.loaded) * elapsedtime - elapsedtime
                    );

                    file_element
                      .find('.upload-progress-bar')
                      .css('width', (e.loaded / e.total) * 100 + '%');
                    file_element
                      .find('.upload-number')
                      .html(
                        Math.round((e.loaded / e.total) * 100) +
                          '%<br><span class="eta">' +
                          duration_helpers.seconds_to_human_time(eta) +
                          '</span>'
                      );
                    if (e.loaded == e.total) {
                      file_element
                        .find('.upload-number')
                        .html(
                          '<i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>'
                        );
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
            if (data.error != undefined) {
              this.resetFileField(file_element);
              file_element
                .addClass('error')
                .append(
                  '<span class="error"><b>Fehler:</b> ' + data.error + '</span>'
                );
            } else {
              file_element.removeClass('uploading').addClass('finished');
              file_element
                .find('.upload-number')
                .html('<i class="fa fa-check" aria-hidden="true"></i>');
              file_element.find('input.file-title').attr('disabled', true);
              file_element.removeAttr('data-file');
              file_element.removeData('file');
              this.files = this.files.filter(e => e !== element);
            }
          })
          .fail(data => {
            this.resetFileField(file_element);
            file_element
              .addClass('error')
              .append(
                '<span class="error"><b>Fehler:</b> ' +
                  data.statusText +
                  '</span>'
              );
          })
      );
    });

    this.checkRequests();
  }
};

AssetUploader.prototype.checkRequests = function() {
  $.when.apply(undefined, this.ajax_requests).then(
    () => {
      this.upload_form.find('.button, #files').attr('disabled', false);
    },
    () => {
      this.upload_form.find('.button, #files').attr('disabled', false);
    }
  );
};

AssetUploader.prototype.validateFiles = function(event) {
  if (event.target.files == undefined || event.target.files.length == 0) return;
  var that = this;
  var new_files = event.target.files;

  this.reveal
    .find('ul.accordion')
    .foundation('up', this.reveal.find('ul.accordion .accordion-content'));

  for (var i = 0; i < new_files.length; i++) {
    var reader = new FileReader();

    reader.onloadstart = (function(the_file) {
      return function(e) {
        if (that.files.filter(f => f.name == the_file.name).length == 0) {
          that.files.push(the_file);

          var file_options = {
            file: the_file,
            target: event.currentTarget,
            html: '<i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>'
          };
          that.renderFileField(file_options);
        } else {
          reader.abort();
        }
      };
    })(new_files[i]);

    reader.onload = (function(the_file) {
      return function(e) {
        var type_validations = [];
        var file_extension = the_file.name.split('.').pop();
        var file_name = the_file.name
          .split('.')
          .shift()
          .replace(/([^A-Za-z0-9[\]{}_.:-])\s?/g, '_');

        for (const key in that.validations) {
          if (that.validations[key].format.indexOf(file_extension) !== -1)
            type_validations.push(that.validations[key]);
        }

        var file_options = {
          file: the_file,
          target: event.currentTarget,
          validations: type_validations,
          file_extension: file_extension,
          file_name: file_name,
          chosen_validation: type_validations[0]
        };

        that.validateFile(file_options);
      };
    })(new_files[i]);

    reader.readAsDataURL(new_files[i]);
  }
};

AssetUploader.prototype.filePrependHTML = function(file_options) {
  return (
    '<input type="text" class="file-title" title="' +
    file_options.file.name +
    '" value="' +
    file_options.file.name +
    '">'
  );
};

AssetUploader.prototype.fileMediaHTML = function(file_options) {
  return (
    '<dl class="file-info"><dt>Format:</dt><dd>' +
    file_options.file.type.split('/').pop() +
    '</dd>, <dt>Größe:</dt><dd>' +
    file_options.file.size.file_size(1) +
    '</dd>'
  );
};

AssetUploader.prototype.fileAppendHTML = function(file_options) {
  var append_html = '';
  if (file_options.validations.length > 1) {
    append_html += '<span class="type-selector">';
    file_options.validations.forEach((validation, index) => {
      append_html +=
        '<input type="radio" id="' +
        file_options.file_name +
        '_' +
        validation.class.replace(/([^A-Za-z0-9[\]{}_.:-])\s?/g, '_') +
        '_selector" name="' +
        file_options.file_name +
        '_radio" value="' +
        validation.class +
        '"' +
        (validation.class == file_options.chosen_validation.class
          ? ' checked="checked"'
          : '') +
        '><label for="' +
        file_options.file_name +
        '_' +
        validation.class.replace(/([^A-Za-z0-9[\]{}_.:-])\s?/g, '_') +
        '_selector">' +
        validation.translation +
        '</label>';
    });
    append_html += '</span>';
  }

  append_html +=
    '<input type="hidden" class="asset-type" name="asset-type" id="' +
    file_options.file_name +
    '_asset_type" value="' +
    (file_options.chosen_type_validation !== undefined
      ? file_options.chosen_type_validation.class
      : null) +
    '">';

  append_html +=
    '<span class="upload-progress"><span class="upload-progress-bar"></span></span>' +
    '<a href="#" class="remove-file"><i aria-hidden="true" class="fa fa-times"></i></a>' +
    '<span class="upload-number"></span>';

  return append_html;
};

AssetUploader.prototype.validateFile = function(file_options = {}) {
  if (this.files.filter(f => f.name == file_options.file.name).length == 0) {
    this.files.push(file_options.file);
  }

  file_options.chosen_type_validation =
    file_options.chosen_validation || file_options.validations[0];

  file_options.prepend_html = this.filePrependHTML(file_options);
  file_options.media_html = this.fileMediaHTML(file_options);
  file_options.append_html = this.fileAppendHTML(file_options);

  file_options.file_url = URL.createObjectURL(file_options.file);

  var validator =
    file_options.chosen_type_validation !== undefined
      ? file_options.chosen_type_validation.class.split('::').pop() +
        'Validator'
      : '';

  if (typeof this[validator] == 'function') {
    this[validator](file_options);
  } else {
    this.DefaultValidator(file_options);
  }
};

AssetUploader.prototype.ImageValidator = function(file_options) {
  var that = this;
  file_options.prepend_html += '<img src="' + file_options.file_url + '">';
  var the_image = new Image();
  the_image.onload = function() {
    file_options.media_html +=
      ', <dt>Abmessungen:</dt><dd>' +
      the_image.naturalWidth +
      'x' +
      the_image.naturalHeight +
      '</dt></dl>';
    file_options.validation_options = {
      width: the_image.naturalWidth,
      height: the_image.naturalHeight
    };
    that.validateAndRender(file_options);
  };
  the_image.onerror = function() {
    file_options.media_html += '</dl>';
    that.validateAndRender(file_options);
  };
  the_image.src = file_options.file_url;
};

AssetUploader.prototype.VideoValidator = function(file_options) {
  var that = this;
  var the_video = document.createElement('video');
  the_video.onloadedmetadata = function() {
    window.URL.revokeObjectURL(this.src);
    file_options.media_html +=
      ', <dt>Abmessungen:</dt><dd>' +
      the_video.videoWidth +
      'x' +
      the_video.videoHeight +
      '</dd>, <dt>Dauer:</dt><dd>' +
      duration_helpers.seconds_to_human_time(the_video.duration) +
      '</dd></dl>';
    file_options.validation_options = {
      width: the_video.videoWidth,
      height: the_video.videoHeight
    };
    that.validateAndRender(file_options);
  };
  the_video.onerror = function() {
    file_options.media_html += '</dl>';
    that.validateAndRender(file_options);
  };
  the_video.setAttribute('src', file_options.file_url);
};

AssetUploader.prototype.DefaultValidator = function(file_options) {
  file_options.media_html += '</dl>';
  this.validateAndRender(file_options);
};

AssetUploader.prototype.validateAndRender = function(file_options) {
  file_options.html =
    file_options.prepend_html +
    file_options.media_html +
    file_options.append_html;
  file_options.valid = this.validate(file_options);

  if (
    file_options.chosen_type_validation !== undefined &&
    !file_options.valid.valid
  ) {
    file_options.html +=
      '<span class="error"><b>Fehler:</b> ' +
      file_options.valid.messages.join(', ') +
      '</span>';
    this.files = this.files.filter(f => f.name != file_options.file.name);
  } else if (file_options.chosen_type_validation === undefined) {
    file_options.html +=
      '<span class="error"><b>Fehler:</b> Nicht unterstützes Format (' +
      file_options.file_extension +
      ')</span>';
    this.files = this.files.filter(f => f.name != file_options.file.name);
  }

  this.renderFileField(file_options);
};

AssetUploader.prototype.validate = function(file_options) {
  var valid = true;
  var messages = [];

  for (var key in file_options.chosen_type_validation) {
    if (typeof this['validate_' + key] == 'function') {
      validation_value = this['validate_' + key](
        file_options,
        file_options.chosen_type_validation[key]
      );
      valid &= validation_value.valid;
      if (validation_value.message !== undefined)
        messages.push(validation_value.message);
    }
  }

  return {
    valid: valid,
    messages: messages
  };
};

AssetUploader.prototype.renderFileField = function(file_options) {
  file_options.file_field = this.reveal.find(
    '.file-for-upload[data-file="' + file_options.file.name + '"]'
  );

  if (!file_options.file_field.length) {
    file_options.file_field = $(
      '<span class="file-for-upload" data-file="' +
        file_options.file.name +
        '"></span>'
    ).insertBefore(file_options.target);
  }

  if (file_options.revalidate) {
    file_options.file_field.find('.error').remove();
    file_options.file_field.append($(file_options.html).filter('.error'));
  } else {
    file_options.file_field.html(file_options.html);
  }

  this.fileFieldEvents(file_options);
};

AssetUploader.prototype.fileFieldEvents = function(file_options) {
  file_options.file_field
    .find(
      '.type-selector input[type="radio"][name="' +
        file_options.file_name +
        '_radio"]'
    )
    .off('change')
    .on('change', e => {
      file_options.chosen_validation = file_options.validations.find(v => {
        return v.class == $(e.target).val();
      });
      file_options.revalidate = true;
      this.validateFile(file_options);
    });

  file_options.file_field
    .find('input.file-title')
    .off('keypress keydown keyup')
    .on('keypress keydown keyup', e => {
      if (e.keyCode == 13) e.preventDefault();
    });
};

AssetUploader.prototype.validate_file_size = function(
  file_options,
  validations
) {
  var messages = '';
  var valid = true;
  if (
    validations.max !== undefined &&
    file_options.file.size > validations.max
  ) {
    valid = false;
    messages += 'Datei zu groß (maximal ' + validations.max.file_size(0) + ')';
  }
  if (
    validations.min !== undefined &&
    file_options.file.size < validations.min
  ) {
    valid = false;
    messages +=
      'Datei zu klein (mindestens ' + validations.min.file_size(0) + ')';
  }

  return {
    valid: valid,
    message: valid ? undefined : messages
  };
};

AssetUploader.prototype.validate_format = function(file_options, validations) {
  var valid = validations.indexOf(file_options.file_extension) !== -1;

  return {
    valid: valid,
    message: valid
      ? undefined
      : 'Nicht unterstützes Format (' + file_options.file_extension + ')'
  };
};

AssetUploader.prototype.validate_dimensions = function(
  file_options,
  validations
) {
  if (file_options.validation_options !== undefined) {
    var additional = object_helpers.reject(validations, [
      'landscape',
      'portrait',
      'exclude'
    ]);
    if (
      object_helpers.get(['exclude', 'format'], validations) !== null &&
      object_helpers
        .get(['exclude', 'format'], validations)
        .indexOf(file_options.file_extension) !== -1
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
          file_options.validation_options.height <=
            additional[key].max.height) ||
          (additional[key].max.width !== undefined &&
            file_options.validation_options.width <= additional[key].max.width))
      ) {
        return {
          valid: true,
          message: undefined
        };
      }
      if (
        additional[key].min !== undefined &&
        ((additional[key].min.height !== undefined &&
          file_options.validation_options.height >=
            additional[key].min.height) ||
          (additional[key].min.width !== undefined &&
            file_options.validation_options.width >= additional[key].min.width))
      ) {
        return {
          valid: true,
          message: undefined
        };
      }
    }

    if (
      (file_options.validation_options.width >=
        file_options.validation_options.height &&
        ((object_helpers.get(['landscape', 'min', 'width'], validations) !==
          null &&
          file_options.validation_options.width <
            validations.landscape.min.width) ||
          (object_helpers.get(['landscape', 'min', 'height'], validations) !==
            null &&
            file_options.validation_options.height <
              validations.landscape.min.height))) ||
      (file_options.validation_options.width <
        file_options.validation_options.height &&
        ((object_helpers.get(['portrait', 'min', 'width'], validations) !==
          null &&
          file_options.validation_options.width <
            validations.portrait.min.width) ||
          (object_helpers.get(['portrait', 'min', 'height'], validations) !==
            null &&
            file_options.validation_options.height <
              validations.portrait.min.height)))
    ) {
      var message =
        'Bild zu klein (' +
        file_options.validation_options.width +
        'x' +
        file_options.validation_options.height +
        '), sollte' +
        (object_helpers.get(['landscape', 'min'], validations) !== null
          ? ' für Querformat mind. ' +
            object_helpers.get(['landscape', 'min', 'width'], validations) +
            'x' +
            object_helpers.get(['landscape', 'min', 'height'], validations)
          : '') +
        (object_helpers.get(['landscape', 'min'], validations) !== null &&
        object_helpers.get(['portrait', 'min'], validations) !== null
          ? ','
          : '') +
        (object_helpers.get(['portrait', 'min'], validations) !== null
          ? ' für Hochformat mind. ' +
            object_helpers.get(['portrait', 'min', 'width'], validations) +
            'x' +
            object_helpers.get(['portrait', 'min', 'height'], validations)
          : '') +
        ' sein.';
      return {
        valid: false,
        message: message
      };
    }

    if (
      (file_options.validation_options.width >=
        file_options.validation_options.height &&
        ((object_helpers.get(['landscape', 'max', 'width'], validations) !==
          null &&
          file_options.validation_options.width >
            validations.landscape.max.width) ||
          (object_helpers.get(['landscape', 'max', 'height'], validations) !==
            null &&
            file_options.validation_options.height >
              validations.landscape.max.height))) ||
      (file_options.validation_options.width <
        file_options.validation_options.height &&
        ((object_helpers.get(['portrait', 'max', 'width'], validations) !==
          null &&
          file_options.validation_options.width >
            validations.portrait.max.width) ||
          (object_helpers.get(['portrait', 'max', 'height'], validations) !==
            null &&
            file_options.validation_options.height >
              validations.portrait.max.height)))
    ) {
      var message =
        'Bild zu groß (' +
        file_options.validation_options.width +
        'x' +
        file_options.validation_options.height +
        '), sollte' +
        (object_helpers.get(['landscape', 'max'], validations) !== null
          ? ' für Querformat max. ' +
            object_helpers.get(['landscape', 'max', 'width'], validations) +
            'x' +
            object_helpers.get(['landscape', 'max', 'height'], validations)
          : '') +
        (object_helpers.get(['landscape', 'max'], validations) !== null &&
        object_helpers.get(['portrait', 'max'], validations) !== null
          ? ','
          : '') +
        (object_helpers.get(['portrait', 'max'], validations) !== null
          ? ' für Hochformat max. ' +
            object_helpers.get(['portrait', 'max', 'width'], validations) +
            'x' +
            object_helpers.get(['portrait', 'max', 'height'], validations)
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
};

AssetUploader.prototype.resetFileField = function(field) {
  $(field).removeClass('uploading error');
  $(field)
    .find('.upload-number')
    .html('');
  $(field)
    .find('.upload-progress-bar')
    .css('width', '0');
};

module.exports = AssetUploader;
