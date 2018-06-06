var Asset = require('./../components/asset');
var duration_helpers = require('./../helpers/duration_helpers');

// Word Counter
module.exports.initialize = function () {

  var assets = [];

  $('.edit-content-form .asset .asset-object').each(function () {
    assets.push(new Asset($(this)));
  });

  $(document).on('clone-added', '.content-object-item', function (event) {
    event.preventDefault();
    event.stopPropagation();
    $(this).find('.asset .asset-object').each(function () {
      assets.push(new Asset($(this)));
    });
  });

  // Upload Form

  let reset_file_field = function (field) {
    field.removeClass('uploading error');
    field.find('.upload-number').html('');
    field.find('.upload-progress-bar').css('width', '0');
  };

  let render_file_field_html = function (target, file_name, html) {
    if ($('#content-upload-reveal .file-for-upload[data-file="' + file_name + '"]').length) {
      $('#content-upload-reveal .file-for-upload[data-file="' + file_name + '"]').html(html);
    } else {
      $(target).before('<span class="file-for-upload" data-file="' + file_name + '">' + html + '</span>');
    }
  };

  let validate_format = function (validations, the_file, media_file) {
    var valid = validations.indexOf(the_file.type.split('/').pop()) !== -1;

    return {
      valid: valid,
      message: valid ? undefined : 'Nicht unterstützes Format (' + the_file.type.split('/').pop() + ')'
    };
  };

  let validate_dimensions = function (validations, the_file, media_file) {
    var valid = true;
    return {
      valid: valid,
      message: valid ? undefined : 'Fehler'
    };
  };

  let validate = function (validations, the_file, media_file) {
    var valid = true;
    var messages = [];

    for (var key in validations) {
      console.log(key);
      if (eval("typeof validate_" + key + " === 'function'")) {
        validation_value = eval('validate_' + key)(validations[key], the_file, media_file);
        valid &= validation_value.valid;
        if (validation_value.message !== undefined) messages.push(validation_value.message);
      }
    }

    return {
      valid: valid,
      messages: messages
    };
  };

  let validate_and_render = function (files, validations, the_file, the_media, target, html) {
    var valid = validate(validations, the_file, the_media);

    if (validations !== undefined && !valid.valid) {
      html += '<span class="error"><b>Fehler:</b> ' + valid.messages.join(', ') + '</span>';
      files = files.filter(f => f.name != the_file.name);
    } else if (validations === undefined) {
      html += '<span class="error"><b>Fehler:</b> Nicht unterstützes Format (' + the_file.type.split('/').pop() + ')</span>';
      files = files.filter(f => f.name != the_file.name);
    }

    render_file_field_html(target, the_file.name, html);
    return files;
  };

  if ($('#content-upload-reveal').length) {
    var files = [];
    var image_validations = $('#content-upload-reveal').data('image-validations');
    var video_validations = $('#content-upload-reveal').data('video-validations');

    $('input[type="file"].upload-file').on('change', event => {
      if (event.target.files != undefined && event.target.files.length > 0) {
        var new_files = event.target.files;

        for (var i = 0; i < new_files.length; i++) {
          var reader = new FileReader();

          reader.onloadstart = function (e) {
            if (files.filter(f => f.name == new_files[i].name).length == 0) {
              files.push(new_files[i]);
              $(event.currentTarget).before('<span class="file-for-upload" data-file="' + new_files[i].name + '"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></span>');
            } else {
              reader.abort();
            }
          };

          reader.onload = (function (the_file) {
            return function (e) {
              var media_html = '<dl class="file-info"><dt>Format:</dt><dd>' + the_file.type.split('/').pop() +
                '</dd>, <dt>Größe:</dt><dd>' + (the_file.size).file_size(1) + '</dd>';

              var prepend_html = '<span class="file-title" title="' + the_file.name + '">' + the_file.name + '</span>';
              var append_html = '<span class="upload-progress"><span class="upload-progress-bar"></span></span>' +
                '<a href="#" class="remove-file"><i aria-hidden="true" class="fa fa-times"></i></a>' +
                '<span class="upload-number"></span>';

              var the_file_url = URL.createObjectURL(the_file);

              if (the_file.type.match(/image.*/)) {
                prepend_html += '<img src="' + the_file_url + '">';
                var the_image = new Image();
                the_image.onload = function () {
                  media_html += ', <dt>Abmessungen:</dt><dd>' + the_image.naturalWidth + 'x' + the_image.naturalHeight + '</dt></dl>';
                  files = validate_and_render(files, image_validations, the_file, the_image, event.currentTarget, prepend_html + media_html + append_html);
                };
                the_image.onerror = function () {
                  media_html += '</dl>';
                  files = validate_and_render(files, image_validations, the_file, undefined, event.currentTarget, prepend_html + media_html + append_html);
                };
                the_image.src = the_file_url;
              } else if (the_file.type.match(/video.*/)) {
                var the_video = document.createElement("video");
                the_video.onloadedmetadata = function () {
                  window.URL.revokeObjectURL(this.src);
                  media_html += ', <dt>Abmessungen:</dt><dd>' + the_video.videoWidth + 'x' + the_video.videoHeight +
                    '</dd>, <dt>Dauer:</dt><dd>' + duration_helpers.seconds_to_human_time(the_video.duration) + '</dd></dl>';
                  files = validate_and_render(files, video_validations, the_file, the_video, event.currentTarget, prepend_html + media_html + append_html);
                };
                the_video.onerror = function () {
                  media_html += '</dl>';
                  files = validate_and_render(files, video_validations, the_file, undefined, event.currentTarget, prepend_html + media_html + append_html);
                };
                the_video.setAttribute('src', the_file_url);
              } else {
                media_html += '</dl>';
                files = validate_and_render(files, undefined, the_file, undefined, event.currentTarget, prepend_html + media_html + append_html);
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
        $('#content-upload-form .button, #content-upload-form #files').attr('disabled', true);
        var ajax_requests = [];
        files.forEach(element => {
          var file_element = $('#content-upload-reveal .file-for-upload[data-file="' + element.name + '"]');
          file_element.removeClass('error finished').addClass('uploading').find('.error').remove();
          var data = new FormData();
          data.append('file', element);

          ajax_requests.push($.ajax({
            url: $(event.currentTarget).attr('action'),
            type: "POST",
            enctype: 'multipart/form-data',
            data: data,
            dataType: 'json',
            processData: false,
            contentType: false,
            cache: false,
            xhr: function () {
              var myXhr = $.ajaxSettings.xhr();
              if (myXhr.upload) {
                myXhr.upload.addEventListener('progress', function (e) {
                  if (e.lengthComputable) {
                    file_element.find('.upload-progress-bar').css('width', (e.loaded / e.total * 100) + '%');
                    file_element.find('.upload-number').text(Math.round(e.loaded / e.total * 100) + '%');
                    if (e.loaded == e.total) {
                      file_element.find('.upload-number').html('<i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>');
                    }
                  }
                }, false);
              }
              return myXhr;
            }
          }).done(data => {
            if (data.error != undefined) {
              reset_file_field(file_element);
              file_element.addClass('error').append('<span class="error"><b>Fehler:</b> ' + data.error + '</span>');
            } else {
              file_element.removeClass('uploading').addClass('finished');
              file_element.find('.remove-file').remove();
              file_element.find('.upload-number').html('<i class="fa fa-check" aria-hidden="true"></i>');
              file_element.removeAttr('data-file');
              file_element.removeData('file');
              files = files.filter(e => e !== element);
            }
          }).fail(data => {
            reset_file_field(file_element);
            file_element.addClass('error').append('<span class="error"><b>Fehler:</b> ' + data.statusText + '</span>');
          }));
        });
        $.when.apply(undefined, ajax_requests).then(() => {
          $('#content-upload-form .button, #content-upload-form #files').attr('disabled', false);
        }, () => {
          $('#content-upload-form .button, #content-upload-form #files').attr('disabled', false);
        });
      }
    });
  }

};
