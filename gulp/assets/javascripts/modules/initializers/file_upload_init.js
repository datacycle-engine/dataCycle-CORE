// Validate PDF File Client Side
var progress_helper = require('./../helpers/progress_helper');
var AjaxQueue = require('./../components/ajax_queue');

module.exports.initialize = function () {

  if ($('#data-link-file-upload-overlay').length) {
    $('#data-link-file-upload-overlay form').attr('data-action', $('#data-link-file-upload-overlay form').prop('action'));

    $('#data-link-file-upload-overlay').on('open.zf.reveal', event => {
      $(event.currentTarget).find('form .warning').remove();
      reset_form($(event.currentTarget).find('form'));
    });

    $('#data-link-file-upload-overlay').on('change', 'form :file', event => {
      $(event.currentTarget).siblings('.warning').remove();
    });

    let ajax_queue = new AjaxQueue();

    // check for existing texts with the same name and change form accordingly
    if ($('#data-link-file-upload-overlay form input.validate-uniqueness').length) {
      $('#data-link-file-upload-overlay').on('input', 'form input.validate-uniqueness', event => {
        var form = $(event.currentTarget).closest('form');
        var submitButton = form.find(':submit').first();

        reset_form(form, true);

        var ajax_request = $.get('/data_links/find', {
          q: $(event.currentTarget).val()
        });

        ajax_queue.queue(ajax_request, ajax_request.done((data) => {
          if (data && data.editable) {
            form.prop('action', form.data('action') + '/' + data.id).prepend('<input name="_method" value="patch" type="hidden">');
            submitButton.html(submitButton.data('update')).attr('disabled', false).data('confirm', 'Die Datei mit dem Namen: ' + data.name + ' wird überschrieben.<br>Fortfahren?');
          } else if (data && !data.editable) {
            submitButton.attr('disabled', true).before('<span class="warning">Name schon vorhanden.</span>');
          } else if (data == null) {
            reset_form(form);
          }
        }));
      });
    }

    // submit the form via ajax, handle progressbar
    $('#data-link-file-upload-overlay').on('submit', 'form', event => {
      event.preventDefault();
      var form = $(event.currentTarget);
      var submitButton = form.find(':submit').first();
      var formdata = false;
      if (window.FormData) {
        formdata = new FormData(form[0]);
      }

      form.find('.warning').remove();
      submitButton.attr('disabled', true);

      $.ajax({
        url: $(event.currentTarget).prop('action'),
        data: formdata ? formdata : form.serialize(),
        cache: false,
        contentType: false,
        processData: false,
        dataType: 'script',
        type: 'POST',
        xhr: () => {
          var myXhr = $.ajaxSettings.xhr();
          if (myXhr.upload) {
            myXhr.upload.addEventListener('progress', e => {
              progress_helper.progress(e, submitButton);
            }, false);
          }
          return myXhr;
        }
      }).fail(data => {
        submitButton.before('<span class="warning">Fehler beim Datei-Upload.</span>');
      }).always(() => {
        submitButton.attr('disabled', false);
      });
    });
  }

  function reset_form(form, disabled_state = false) {
    var submitButton = form.find(':submit').first();

    form.find('.warning').remove();
    form.prop('action', form.data('action')).find('input:hidden[name="_method"]').remove();
    submitButton.html(submitButton.data('create')).attr('disabled', disabled_state).removeData('confirm');
  }
};
