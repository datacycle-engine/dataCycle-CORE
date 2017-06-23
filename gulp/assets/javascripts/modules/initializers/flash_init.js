// Add Timeout to slideup Flash Messages
module.exports.initialize = function () {

  //schickt flash callout success nach oben
  if ($('div.flash.callout').length) {
    $("div.flash.callout").parent('div').removeAttr('style');
    $('body').prepend($("body").find("div.flash.callout"));
    $("div.flash.callout").show();
    setTimeout(function () { $("div.flash.callout.success").slideUp("slow"); }, 4000);
  }

};