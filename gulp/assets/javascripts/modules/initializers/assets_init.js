var Asset = require('./../components/asset');

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

  if ($('#content-upload-reveal').length) {
    var files = [];
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
              var media_html = '';
              if (the_file.type.match(/image.*/) && the_file.size < 10000000) media_html += '<img src="' + e.target.result + '">';
              media_html += '<span class="file-title">' + the_file.name + '</span><span class="upload-progress"><span class="upload-progress-bar"></span></span><a href="#" class="remove-file"><i aria-hidden="true" class="fa fa-times"></i></a><span class="upload-number"></span>';

              if ($('#content-upload-reveal .file-for-upload[data-file="' + the_file.name + '"]').length) {
                $('#content-upload-reveal .file-for-upload[data-file="' + the_file.name + '"]').html(media_html);
              } else {
                $(event.currentTarget).before('<span class="file-for-upload" data-file="' + the_file.name + '">' + media_html + '</span>');
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
