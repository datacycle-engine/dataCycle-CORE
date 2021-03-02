import ConfirmationModal from '~/javascripts/components/confirmation_modal';

// Override Rails Confirmation Popup
export default function () {
  $.rails.allowAction = function (link) {
    if (link.data('confirm') == undefined) {
      return true;
    }
    $.rails.showConfirmationDialog(link);
    return false;
  };

  //User click confirm button
  $.rails.confirmed = function (link) {
    link.data('confirm', null);
    link.trigger('click.rails');
  };

  //Display the confirmation dialog
  $.rails.showConfirmationDialog = function (link) {
    var message = link.data('confirm');

    var confirmationModal = new ConfirmationModal({
      text: message,
      confirmationClass: 'alert',
      cancelable: true,
      confirmationCallback: function () {
        $.rails.confirmed(link);
      }
    });
  };
}
