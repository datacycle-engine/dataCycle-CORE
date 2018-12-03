// Reveal Blur
module.exports.initialize = function () {

  $('.remote-render:visible').each((index, element) => {
    load_remote_partial(element);
  });

  $(document).on('open.zf.reveal', event => {
    $(event.target).find('.remote-render:visible').addBack('.remote-render:visible').each((index, element) => {
      load_remote_partial(element);
    });
  });

  function load_remote_partial(element) {
    $(element).html('<div class="loading show"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');

    $.ajax({
      type: 'POST',
      url: '/remote_render',
      data: JSON.stringify({
        target: $(element).prop('id'),
        partial: $(element).data('remotePath'),
        content_for: $(element).data('remoteContentFor'),
        options: $(element).data('remoteOptions'),
        render_function: $(element).data('remoteRenderFunction'),
        render_params: $(element).data('remoteRenderParams')
      }),
      dataType: 'script',
      contentType: 'application/json'
    }).done(data => {
      $(element).toggleClass('remote-render remote-rendered');
    }).fail(data => {
      if (data.responseText !== undefined) $(element).html(data.responseText);
      else $(target + ':visible').html('Fehler beim Laden des Inhalts.');
    });
  };

};
