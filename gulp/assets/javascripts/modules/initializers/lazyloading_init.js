// Add Lazyloading + fixes
module.exports.initialize = function() {
  // reposition reveal after it is loaded
  $(document).on('changed.dc.html lazyloaded', '*', event => {
    event.stopPropagation();
    let reveal = $(event.target).closest('.reveal:not(.full)');
    if (reveal.length && (reveal.data('v-offset') === 'auto' || reveal.data('v-offset') === undefined))
      reveal.foundation('_updatePosition');
  });

  $(document).on('lazybeforeunveil', 'iframe', event => {
    event.stopPropagation();
    $(event.target).after('<div class="loading-iframe"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  });

  $(document).on('lazyloaded', 'iframe', event => {
    event.stopPropagation();
    $(event.target)
      .siblings('.loading-iframe')
      .remove();
  });

  $(document).on('closed.zf.reveal', event => {
    event.stopPropagation();
    $(event.target)
      .find('iframe')
      .removeClass('lazyloaded lazyloading')
      .addClass('lazyload');
  });
};
