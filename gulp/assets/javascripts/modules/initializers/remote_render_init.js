var RandomHelpers = require('./../helpers/random_number_helpers');

// Reveal Blur
module.exports.initialize = function() {
  $('.remote-render:visible').each((_, element) => {
    if (!$(element).closest('.dropdown-pane').length) load_remote_partial(element);
  });

  $(document).on('change.zf.tabs', event => {
    event.stopPropagation();
    $(event.target)
      .siblings('[data-tabs-content]')
      .find('.remote-render:visible')
      .each((_, element) => {
        load_remote_partial(element);
      });
  });

  $(document).on(
    'open.zf.reveal dc:remote:render dc:html:changed show.zf.dropdown dc:toggler:show down.zf.accordion',
    '*',
    (event, data) => {
      event.stopPropagation();

      let items = $(event.target)
        .find('.remote-render')
        .addBack('.remote-render');

      if (!data || !data.force)
        items = items.filter((_, elem) => {
          return $(elem).css('visibility') != 'hidden' && $(elem).is(':visible');
        });

      items.each((_, element) => {
        load_remote_partial(element);
      });
    }
  );

  function load_remote_partial(element) {
    let id = RandomHelpers.generateRandomId();
    element.setAttribute('data-remote-render-id', id);
    $(element)
      .removeClass('remote-render')
      .addClass('remote-rendering')
      .html('<div class="loading show"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');

    $.ajax({
      type: 'POST',
      url: '/remote_render',
      data: JSON.stringify({
        target: id,
        partial: $(element).data('remotePath'),
        content_for: $(element).data('remoteContentFor'),
        options: $(element).data('remoteOptions'),
        render_function: $(element).data('remoteRenderFunction'),
        render_params: $(element).data('remoteRenderParams')
      }),
      dataType: 'script',
      contentType: 'application/json'
    }).fail(data => {
      if (data.responseText !== undefined) $(element).html(data.responseText);
      else $(target + ':visible').html('Fehler beim Laden des Inhalts.');
    });
  }
};
