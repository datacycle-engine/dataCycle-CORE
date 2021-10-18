import 'foundation-sites';

function removeFoundationOverlays(element, type) {
  let overlay = document.getElementById(element.dataset[type]);
  if (!overlay || document.querySelector(`[data-${type}="${overlay.id}"]`)) return;
  if (overlay.parentElement.classList.contains('reveal-overlay')) overlay = overlay.parentElement;

  overlay.remove();
}

export default function () {
  Foundation.Tooltip.defaults.clickOpen = false;
  Foundation.Reveal.defaults.closeOnClick = false;
  Foundation.Reveal.defaults.multipleOpened = true;
  Foundation.Dropdown.defaults.position = 'bottom';
  Foundation.Dropdown.defaults.alignment = 'left';
  Foundation.Dropdown.defaults.hover = true;
  Foundation.Dropdown.defaults.hoverPane = true;
  Foundation.addToJquery($);

  DataCycle.htmlObserver.removeCallbacks.push([e => 'open' in e.dataset, e => removeFoundationOverlays(e, 'open')]);
  DataCycle.htmlObserver.removeCallbacks.push([e => 'toggle' in e.dataset, e => removeFoundationOverlays(e, 'toggle')]);

  $('body').foundation().addClass('dc-fd-initialized');

  $(document).on('dc:html:changed dc:contents:added', '*:not(.dc-fd-initialized)', event => {
    event.stopPropagation();

    const $target = $(event.currentTarget);

    if ($target.hasClass('accordion-item')) Foundation.reInit($target.closest('[data-accordion]'));
    if ($target.hasClass('accordion')) Foundation.reInit($target);
    $target.foundation().addClass('dc-fd-initialized');
  });

  $(document).on('open.zf.reveal', '.reveal', event => {
    event.stopPropagation();

    const $target = $(event.currentTarget);

    $('.reveal:visible, .reveal-overlay:visible').css('z-index', '');
    $target.add($target.parent('.reveal-overlay')).css('z-index', 1007);
  });

  $(document).on('closed.zf.reveal', '.reveal', event => {
    event.stopPropagation();

    const previousReveal = $('.reveal:visible').last();

    previousReveal.add(previousReveal.parent('.reveal-overlay')).css('z-index', 1007);
  });

  $(document).on('closed.zf.reveal', '.reveal', event => {
    event.stopPropagation();

    const $target = $(event.currentTarget);

    if ($target.find('video').length) $target.find('video').get(0).pause();
  });

  $(document).on('remove', '*', event => {
    event.stopPropagation();
  });

  $(document).on('dc:html:remove', '*', event => {
    event.stopPropagation();

    const $target = $(event.currentTarget);

    $target.find('[data-open]').each((i, elem) => {
      if ($('#' + $(elem).data('open')).parent('.reveal-overlay').length)
        $('#' + $(elem).data('open'))
          .trigger('dc:html:remove')
          .parent('.reveal-overlay')
          .remove();
      else
        $('#' + $(elem).data('open'))
          .trigger('dc:html:remove')
          .remove();
    });
    $target.find('[data-toggle]').each((i, elem) => {
      if ($('#' + $(elem).data('toggle')).parent('.reveal-overlay').length)
        $('#' + $(elem).data('toggle'))
          .trigger('dc:html:remove')
          .parent('.reveal-overlay')
          .remove();
      else
        $('#' + $(elem).data('toggle'))
          .trigger('dc:html:remove')
          .remove();
    });
  });

  $(document).on('click', 'div.accordion-title', event => {
    if ($(event.target).closest('a').length) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    $(event.currentTarget)
      .closest('[data-accordion]')
      .foundation('toggle', $(event.currentTarget).closest('.accordion-title').siblings('.accordion-content'));
  });

  $(document).on('mouseenter', '.dc-foundation-tooltip', event => {
    let $target = $(event.currentTarget);
    $target.removeClass('dc-foundation-tooltip');

    if ($target.prop('title').length) {
      new Foundation.Tooltip($target);
      $target.trigger('mouseenter');
    }
  });
}
