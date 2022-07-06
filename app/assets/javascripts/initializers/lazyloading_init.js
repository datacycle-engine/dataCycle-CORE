import loadingIcon from '../templates/loadingIcon';

function monitorSizeChanges(element) {
  const resizeObserver = new ResizeObserver(_ => $(element).foundation('_updatePosition'));
  resizeObserver.observe(element);
}

export default function () {
  for (const element of document.querySelectorAll(
    '.reveal:not(.full)[data-v-offset="auto"], .reveal:not(.full):not([data-v-offset])'
  ))
    monitorSizeChanges(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('reveal') &&
      !e.classList.contains('full') &&
      (e.dataset.vOffset == 'auto' || !e.dataset.vOffset),
    e => monitorSizeChanges(e)
  ]);

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
