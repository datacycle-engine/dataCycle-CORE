// Add Lazyloading + fixes
module.exports.initialize = function() {
  // reposition reveal after it is loaded
  $(document).on('changed.dc.html', '*', event => {
    event.stopPropagation();
    if ($(event.target).closest('.reveal:not(.object-browser-overlay)').length) {
      console.log($(event.target).closest('.reveal:not(.object-browser-overlay)'));
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
    if ($(event.target).hasClass('lazyloaded')) {
      console.log('reposition');
      $(event.target)
        .closest('.reveal:not(.object-browser-overlay)')
        .foundation('open');
    }
  });

  $(document).on('closed.zf.reveal', event => {
    $(event.target)
      .find('iframe')
      .removeClass('lazyloaded lazyloading')
      .addClass('lazyload');
  });
};
