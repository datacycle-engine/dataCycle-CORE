// Reveal Blur
module.exports.initialize = function () {

  $(document).on('open.zf.reveal', '.reveal[data-remote-path]:not(.loaded)', event => {
    var target = $(event.target).data('remoteTarget');
    $.ajax({
      type: 'GET',
      url: '/remote_render',
      data: {
        target: target,
        partial: $(event.target).data('remotePath'),
        options: $(event.target).data('remoteOptions')
      },
      dataType: 'script',
      contentType: 'application/json'
    }).fail(() => {
      if (target !== undefined) {
        $(target).html('Fehler beim Laden des Inhalts.');
      } else {
        $(event.target).html('Fehler beim Laden des Inhalts.');
      }
    });
  });

};
