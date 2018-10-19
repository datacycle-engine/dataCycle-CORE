// Reveal Blur
module.exports.initialize = function () {

  $(document).on('open.zf.reveal', '.reveal[data-remote-path]:not(.loaded)', event => {
    var target = $(event.target).data('remoteTarget') || '#' + $(event.target).prop('id');
    $.ajax({
      type: 'POST',
      url: '/remote_render',
      data: JSON.stringify({
        target: target,
        partial: $(event.target).data('remotePath'),
        content_for: $(event.target).data('remoteContentFor'),
        options: $(event.target).data('remoteOptions')
      }),
      dataType: 'script',
      contentType: 'application/json'
    }).fail(data => {
      if (data.responseText !== undefined) $(target + ':visible').html(data.responseText);
      else $(target + ':visible').html('Fehler beim Laden des Inhalts.');
    });
  });

};
