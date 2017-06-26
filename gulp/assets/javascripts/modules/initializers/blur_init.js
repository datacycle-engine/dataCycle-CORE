// Reveal Blur 
module.exports.initialize = function () {

  // schöner blur-BG beim newObject Button
  $('#new-object, #mediabrowser').on('open.zf.reveal', function () {
    //$('.off-canvas-content').prepend($('.reveal-overlay'));
    $('.reveal-blur').addClass("show");
    window.scrollTo(0, 0);
  });
  $('#new-object, #mediabrowser').on('closed.zf.reveal', function () {
    $('.reveal-blur').removeClass("show");
  });

};
