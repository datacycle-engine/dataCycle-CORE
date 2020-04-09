var ConfirmationModal = require('./../components/confirmation_modal');

// Check if user is still logged in
module.exports.initialize = function ($) {
  if ($('.edit-content-form').length) {
    let today = new Date();
    let id = $('.edit-content-form').find(':input[name="uuid"]').val();
    let table = $('.edit-content-form').find(':input[name="table"]').val();

    addReloadTimeout();

    function addReloadTimeout() {
      setTimeout(() => {
        $(window)
          .off('focus.dc_edit_page')
          .on('focus.dc_edit_page', event => {
            $.ajax({
              type: 'GET',
              url: window.DATA_CYCLE_ENGINE_PATH + '/reload_required',
              data: {
                id: id,
                table: table,
                datestring: today.toISOString()
              },
              dataType: 'json',
              contentType: 'application/json'
            }).always(data => {
              $(window).off('focus.dc_edit_page');

              if (
                data !== undefined &&
                data.error !== undefined &&
                !$('.confirmation-modal section.confirmation-section:contains(' + data.error + ')').length
              )
                new ConfirmationModal({
                  text: data.error,
                  confirmationClass: 'success',
                  cancelable: true,
                  confirmationText: data.confirmation_text || 'Seite neu laden',
                  confirmationCallback: () => {
                    location.reload();
                  },
                  cancelCallback: () => {
                    addReloadTimeout();
                  }
                });
              else addReloadTimeout();
            });
          });
      }, 300000);
    }
  }
};
