// Add Lazyloading + fixes
module.exports.initialize = function() {
  // reposition reveal after it is loaded
  $(document).on('lazyloaded changed.dc.html', '*', event => {
    if ($(event.target).closest('.reveal:not(.object-browser-overlay)').length) {
      $(event.target)
        .closest('.reveal:not(.object-browser-overlay)')
        .foundation('open');
    }
  });

  $(document).on('lazybeforeunveil', 'iframe', event => {
    $(event.target).after('<div class="loading-iframe"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  });

  $(document).on('lazyloaded', 'iframe', event => {
    $(event.target)
      .siblings('.loading-iframe')
      .remove();
  });

  $(document).on('closed.zf.reveal', event => {
    $(event.target)
      .find('iframe')
      .removeClass('lazyloaded lazyloading')
      .addClass('lazyload');
  });
};
