// Reveal Blur
module.exports.initialize = function () {

  $(document).on('ajax:before', '.new-content-reveal [data-remote]', (xhr, options) => {
    $(xhr.target).closest('.new-content-reveal').find('.new-content-form').html('<div class="loading show"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  });

  $(document).on('ajax:error', '.new-content-reveal [data-remote]', (response, status, xhr) => {
    $(xhr.target).closest('.new-content-reveal').find('.new-content-form').html('Fehler beim Laden des Inhalts.');
  });

};
