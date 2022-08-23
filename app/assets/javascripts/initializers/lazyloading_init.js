import loadingIcon from '../templates/loadingIcon';

export default function () {
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
