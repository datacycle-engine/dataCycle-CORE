import loadingIcon from '../templates/loadingIcon';

export default function () {
  // reposition reveal after it is loaded
  $(document).on('dc:html:changed lazyloaded', '*', event => {
    event.stopPropagation();
    let reveal = $(event.target).closest('.reveal:not(.full)');
    if (reveal.length && (reveal.data('v-offset') === 'auto' || reveal.data('v-offset') === undefined))
      reveal.foundation('_updatePosition');
  });

  $(document).on('lazybeforeunveil', 'iframe', event => {
    event.stopPropagation();
    $(event.target).after(loadingIcon('loading-iframe'));
  });

  $(document).on('lazyloaded', 'iframe', event => {
    event.stopPropagation();
    $(event.target).siblings('.loading-iframe').remove();
  });

  $(document).on('closed.zf.reveal', event => {
    event.stopPropagation();
    $(event.target).find('iframe').removeClass('lazyloaded lazyloading').addClass('lazyload');
  });
}
