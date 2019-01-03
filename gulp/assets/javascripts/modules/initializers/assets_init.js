var Asset = require('./../components/asset');
var duration_helpers = require('./../helpers/duration_helpers');
var object_helpers = require('./../helpers/object_helpers');

// Word Counter
module.exports.initialize = function() {
  var assets = [];

  $('.edit-content-form .asset .asset-object').each(function() {
    assets.push(new Asset($(this)));
  });

  $(document).on('clone-added', '.content-object-item', function(event) {
    event.preventDefault();
    event.stopPropagation();
    $(this)
      .find('.asset .asset-object')
      .each(function() {
        assets.push(new Asset($(this)));
      });
  });

  function reject(obj, keys) {
    return Object.keys(obj)
      .filter(k => !keys.includes(k))
      .map(k =>
        Object.assign(
          {},
          {
            [k]: obj[k]
          }
        )
      )
      .reduce((res, o) => Object.assign(res, o), {});
  }

  // Upload Form

  let reset_file_field = function(field) {
    field.removeClass('uploading error');
    field.find('.upload-number').html('');
    field.find('.upload-progress-bar').css('width', '0');
  };

  let render_file_field_html = function(target, file_name, html) {
    if (
      $(
        '#content-upload-reveal .file-for-upload[data-file="' + file_name + '"]'
      ).length
    ) {
      $(
        '#content-upload-reveal .file-for-upload[data-file="' + file_name + '"]'
      ).html(html);
    } else {
      $(target).before(
        '<span class="file-for-upload" data-file="' +
          file_name +
          '">' +
          html +
          '</span>'
      );
    }
  };

  let validate_format = function(validations, the_file, media_params) {
    var valid = validations.indexOf(the_file.name.split('.').pop()) !== -1;

    return {
      valid: valid,
      message: valid
        ? undefined
        : 'Nicht unterstützes Format (' + the_file.name.split('.').pop() + ')'
    };
  };

  let validate_dimensions = function(validations, the_file, media_params) {
    if (media_params !== undefined) {
      var additional = reject(validations, [
        'landscape',
        'portrait',
        'exclude'
      ]);
      if (
        object_helpers.get(['exclude', 'format'], validations) !== null &&
        object_helpers
          .get(['exclude', 'format'], validations)
          .indexOf(the_file.type.split('/').pop()) !== -1
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
            media_params.height <= additional[key].max.height) ||
            (additional[key].max.width !== undefined &&
              media_params.width <= additional[key].max.width))
        ) {
          return {
            valid: true,
            message: undefined
          };
        }
        if (
          additional[key].min !== undefined &&
          ((additional[key].min.height !== undefined &&
            media_params.height >= additional[key].min.height) ||
            (additional[key].min.width !== undefined &&
              media_params.width >= additional[key].min.width))
        ) {
          return {
            valid: true,
            message: undefined
          };
        }
      }

      if (
        (media_params.width >= media_params.height &&
          ((object_helpers.get(['landscape', 'min', 'width'], validations) !==
            null &&
            media_params.width < validations.landscape.min.width) ||
            (object_helpers.get(['landscape', 'min', 'height'], validations) !==
              null &&
              media_params.height < validations.landscape.min.height))) ||
        (media_params.width < media_params.height &&
          ((object_helpers.get(['portrait', 'min', 'width'], validations) !==
            null &&
            media_params.width < validations.portrait.min.width) ||
            (object_helpers.get(['portrait', 'min', 'height'], validations) !==
              null &&
              media_params.height < validations.portrait.min.height)))
      ) {
        var message =
          'Bild zu klein (' +
          media_params.width +
          'x' +
          media_params.height +
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
        (media_params.width >= media_params.height &&
          ((object_helpers.get(['landscape', 'max', 'width'], validations) !==
            null &&
            media_params.width > validations.landscape.max.width) ||
            (object_helpers.get(['landscape', 'max', 'height'], validations) !==
              null &&
              media_params.height > validations.landscape.max.height))) ||
        (media_params.width < media_params.height &&
          ((object_helpers.get(['portrait', 'max', 'width'], validations) !==
            null &&
            media_params.width > validations.portrait.max.width) ||
            (object_helpers.get(['portrait', 'max', 'height'], validations) !==
              null &&
              media_params.height > validations.portrait.max.height)))
      ) {
        var message =
          'Bild zu groß (' +
          media_params.width +
          'x' +
          media_params.height +
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

  let validate = function(validations, the_file, media_params) {
    var valid = true;
    var messages = [];

    for (var key in validations) {
      if (eval('typeof validate_' + key + " === 'function'")) {
        validation_value = eval('validate_' + key)(
          validations[key],
          the_file,
          media_params
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

  let validate_and_render = function(
    files,
    validations,
    the_file,
    media_params,
    target,
    html
  ) {
    var valid = validate(validations, the_file, media_params);

    if (validations !== undefined && !valid.valid) {
      html +=
        '<span class="error"><b>Fehler:</b> ' +
        valid.messages.join(', ') +
        '</span>';
      files = files.filter(f => f.name != the_file.name);
    } else if (validations === undefined) {
      html +=
        '<span class="error"><b>Fehler:</b> Nicht unterstützes Format (' +
        the_file.name.split('.').pop() +
        ')</span>';
      files = files.filter(f => f.name != the_file.name);
    }

    render_file_field_html(target, the_file.name, html);
    return files;
  };

  if ($('#content-upload-reveal').length) {
    $('#content-upload-reveal').on('open.zf.reveal', event => {
      $(event.currentTarget)
        .parent('.reveal-overlay')
        .addClass('content-reveal-overlay');
    });
    var files = [];
    var validations = $('#content-upload-reveal').data('validations');

    $('input[type="file"].upload-file').on('change', event => {
      if (event.target.files != undefined && event.target.files.length > 0) {
        var new_files = event.target.files;

        for (var i = 0; i < new_files.length; i++) {
          var reader = new FileReader();

          reader.onloadstart = (function(the_file) {
            return function(e) {
              if (files.filter(f => f.name == the_file.name).length == 0) {
                files.push(the_file);
                $(event.currentTarget).before(
                  '<span class="file-for-upload" data-file="' +
                    the_file.name +
                    '"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></span>'
                );
              } else {
                reader.abort();
              }
            };
          })(new_files[i]);

          reader.onload = (function(the_file) {
            return function(e) {
              var media_html =
                '<dl class="file-info"><dt>Format:</dt><dd>' +
                the_file.type.split('/').pop() +
                '</dd>, <dt>Größe:</dt><dd>' +
                the_file.size.file_size(1) +
                '</dd>';

              var prepend_html =
                '<span class="file-title" title="' +
                the_file.name +
                '">' +
                the_file.name +
                '</span>';
              var append_html =
                '<span class="upload-progress"><span class="upload-progress-bar"></span></span>' +
                '<a href="#" class="remove-file"><i aria-hidden="true" class="fa fa-times"></i></a>' +
                '<span class="upload-number"></span>';

              var the_file_url = URL.createObjectURL(the_file);

              if (the_file.type.match(/image.*/)) {
                prepend_html += '<img src="' + the_file_url + '">';
                var the_image = new Image();
                the_image.onload = function() {
                  media_html +=
                    ', <dt>Abmessungen:</dt><dd>' +
                    the_image.naturalWidth +
                    'x' +
                    the_image.naturalHeight +
                    '</dt></dl>';
                  files = validate_and_render(
                    files,
                    validations.image,
                    the_file,
                    {
                      width: the_image.naturalWidth,
                      height: the_image.naturalHeight
                    },
                    event.currentTarget,
                    prepend_html + media_html + append_html
                  );
                };
                the_image.onerror = function() {
                  media_html += '</dl>';
                  files = validate_and_render(
                    files,
                    validations.image,
                    the_file,
                    undefined,
                    event.currentTarget,
                    prepend_html + media_html + append_html
                  );
                };
                the_image.src = the_file_url;
              } else if (the_file.type.match(/video.*/)) {
                var the_video = document.createElement('video');
                the_video.onloadedmetadata = function() {
                  window.URL.revokeObjectURL(this.src);
                  media_html +=
                    ', <dt>Abmessungen:</dt><dd>' +
                    the_video.videoWidth +
                    'x' +
                    the_video.videoHeight +
                    '</dd>, <dt>Dauer:</dt><dd>' +
                    duration_helpers.seconds_to_human_time(the_video.duration) +
                    '</dd></dl>';
                  files = validate_and_render(
                    files,
                    validations.video,
                    the_file,
                    {
                      width: the_video.videoWidth,
                      height: the_video.videoHeight
                    },
                    event.currentTarget,
                    prepend_html + media_html + append_html
                  );
                };
                the_video.onerror = function() {
                  media_html += '</dl>';
                  files = validate_and_render(
                    files,
                    validations.video,
                    the_file,
                    undefined,
                    event.currentTarget,
                    prepend_html + media_html + append_html
                  );
                };
                the_video.setAttribute('src', the_file_url);
              } else if (the_file.type.match(/application.pdf/)) {
                media_html += '</dl>';
                files = validate_and_render(
                  files,
                  validations.pdf,
                  the_file,
                  undefined,
                  event.currentTarget,
                  prepend_html + media_html + append_html
                );
              } else if (the_file.type.match(/application.*/)) {
                media_html += '</dl>';
                files = validate_and_render(
                  files,
                  validations.file,
                  the_file,
                  undefined,
                  event.currentTarget,
                  prepend_html + media_html + append_html
                );
              } else {
                media_html += '</dl>';
                files = validate_and_render(
                  files,
                  undefined,
                  the_file,
                  undefined,
                  event.currentTarget,
                  prepend_html + media_html + append_html
                );
              }
            };
          })(new_files[i]);

          reader.readAsDataURL(new_files[i]);
        }
      }
    });

    $('#content-upload-reveal').on('click', 'a.remove-file', event => {
      var target = $(event.currentTarget).parent();
      files = files.filter(f => f.name != target.data('file'));
      target.remove();
    });

    $('#content-upload-form').on('submit', event => {
      event.preventDefault();

      if (files.length > 0) {
        $('#content-upload-form .button, #content-upload-form #files').attr(
          'disabled',
          true
        );
        var ajax_requests = [];

        files.forEach(element => {
          var file_element = $(
            '#content-upload-reveal .file-for-upload[data-file="' +
              element.name +
              '"]'
          );
          file_element
            .removeClass('error finished')
            .addClass('uploading')
            .find('.error')
            .remove();
          var data = new FormData();
          data.append(
            'asset[uploader]',
            element.type
              .replace('application/pdf', 'pdf')
              .replace('application', 'file')
              .split('/')
              .shift()
          );
          data.append('asset[file]', element);

          var startTime = new Date().getTime();

          ajax_requests.push(
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
                        var elapsedtime =
                          (new Date().getTime() - startTime) / 1000;
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
                  reset_file_field(file_element);
                  file_element
                    .addClass('error')
                    .append(
                      '<span class="error"><b>Fehler:</b> ' +
                        data.error +
                        '</span>'
                    );
                } else {
                  file_element.removeClass('uploading').addClass('finished');
                  file_element
                    .find('.upload-number')
                    .html('<i class="fa fa-check" aria-hidden="true"></i>');
                  file_element.removeAttr('data-file');
                  file_element.removeData('file');
                  files = files.filter(e => e !== element);
                }
              })
              .fail(data => {
                reset_file_field(file_element);
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
        $.when.apply(undefined, ajax_requests).then(
          () => {
            $('#content-upload-form .button, #content-upload-form #files').attr(
              'disabled',
              false
            );
          },
          () => {
            $('#content-upload-form .button, #content-upload-form #files').attr(
              'disabled',
              false
            );
          }
        );
      }
    });

    // prevent leaving Site while uploading!
    $(window).on('beforeunload', event => {
      if ($('.file-for-upload.uploading').length)
        return 'Es gibt noch laufende Uploads!';
    });
  }
};
