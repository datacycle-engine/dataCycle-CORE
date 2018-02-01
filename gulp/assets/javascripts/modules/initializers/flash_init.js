var ConfirmationModal = require('./../components/confirmation_modal');

// Add Timeout to slideup Flash Messages
module.exports.initialize = function () {

  //schickt flash callout success nach oben
  if ($('div.flash.callout').length) {
    $("div.flash.callout").parent('div').removeAttr('style');
    $('body').prepend($("body").find("div.flash.callout"));
    $("div.flash.callout").show();
    setTimeout(function () {
      $("div.flash.callout.success").slideUp("slow");
    }, 4000);
  }

  $('.close-subscribe-notice').on('click', function (ev) {
    ev.preventDefault();
    $(this).closest('.subscribe-parent').hide();
  });


  $.rails.allowAction = function (link) {
    if (link.data("confirm") == undefined) {
      return true;
    }
    $.rails.showConfirmationDialog(link);
    return false;
  }
  //User click confirm button
  $.rails.confirmed = function (link) {
    link.data("confirm", null);
    link.trigger("click.rails");
  }
  //Display the confirmation dialog
  $.rails.showConfirmationDialog = function (link) {
    var message = link.data("confirm");

    var confirmationModal = new ConfirmationModal(message, 'alert', true, function () {
      $.rails.confirmed(link);
    });
  }


};
