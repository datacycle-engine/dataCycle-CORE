import ConfirmationModal from './../components/confirmation_modal';

export default function () {
  if ($('.edit-content-form').length) {
    let today = new Date();
    let id = $('.edit-content-form').find(':input[name="uuid"]').val();
    let table = $('.edit-content-form').find(':input[name="table"]').val();

    addReloadTimeout();

    function addReloadTimeout() {
      setTimeout(() => {
        $(window).off('focus.dc_edit_page', reloadRequiredHandler).on('focus.dc_edit_page', reloadRequiredHandler);
      }, 300000);
    }

    function reloadRequiredHandler(_event) {
      DataCycle.httpRequest({
        method: 'GET',
        url: '/reload_required',
        data: {
          id: id,
          table: table,
          datestring: today.toISOString()
        },
        dataType: 'json',
        contentType: 'application/json'
      })
        .then(async data => {
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
              confirmationText: data.confirmation_text || (await I18n.translate('frontend.reload_page')),
              confirmationCallback: () => {
                location.reload();
              },
              cancelCallback: () => {
                addReloadTimeout();
              }
            });
          else addReloadTimeout();
        })
        .catch(response => {
          console.warn(response.statusText);
        });
    }
  }
}
