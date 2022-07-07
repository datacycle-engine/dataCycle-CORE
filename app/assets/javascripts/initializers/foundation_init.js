import 'foundation-sites';
import domElementHelpers from '../helpers/dom_element_helpers';

function removeFoundationOverlays(element, type) {
  let overlay = document.getElementById(element.dataset[type]);
  if (!overlay || document.querySelector(`[data-${type}="${overlay.id}"]`)) return;
  if (overlay.parentElement.classList.contains('reveal-overlay')) overlay = overlay.parentElement;

  overlay.remove();
}

function initReveal(element) {
  new Foundation.Reveal($(element));
  element.classList.add('dc-fd-reveal');

  if (element.dataset.initialState == 'open') $(element).foundation('open');
}

function monitorSizeChanges(element) {
  const resizeObserver = new ResizeObserver(_ => {
    if (domElementHelpers.isVisible(element)) $(element).foundation('_updatePosition');
  });

  resizeObserver.observe(element);
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

  // Foundation Slider
  for (const element of document.querySelectorAll('.slider')) new Foundation.Slider($(element));
  DataCycle.htmlObserver.addCallbacks.push([e => e.classList.contains('slider'), e => new Foundation.Slider($(e))]);

  // Foundation Accordion
  for (const element of document.querySelectorAll('[data-accordion]')) {
    new Foundation.Accordion($(element));
    element.classList.add('dc-fd-accordion');
  }
  DataCycle.htmlObserver.addCallbacks.push([
    e => 'accordion' in e.dataset,
    e => {
      new Foundation.Accordion($(e));
      e.classList.add('dc-fd-accordion');
    }
  ]);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('accordion-item') && e.closest('[data-accordion]').classList.contains('dc-fd-accordion'),
    e => Foundation.reInit($(e.closest('[data-accordion]')))
  ]);

  // Foundation Dropdown
  for (const element of document.querySelectorAll('[data-dropdown]')) new Foundation.Dropdown($(element));
  DataCycle.htmlObserver.addCallbacks.push([e => 'dropdown' in e.dataset, e => new Foundation.Dropdown($(e))]);

  // Foundation OffCanvas
  for (const element of document.querySelectorAll('[data-off-canvas]')) new Foundation.OffCanvas($(element));
  DataCycle.htmlObserver.addCallbacks.push([e => 'offCanvas' in e.dataset, e => new Foundation.OffCanvas($(e))]);

  // Foundation Reveal
  for (const element of document.querySelectorAll('[data-reveal]')) initReveal(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => 'reveal' in e.dataset && !e.classList.contains('dc-fd-reveal'),
    e => initReveal(e)
  ]);

  // Foundation Reveal Position Updater
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

  // Foundation Tabs
  for (const element of document.querySelectorAll('[data-tabs]')) new Foundation.Tabs($(element));
  DataCycle.htmlObserver.addCallbacks.push([e => 'tabs' in e.dataset, e => new Foundation.Tabs($(e))]);

  // Foundation Tooltip
  for (const element of document.querySelectorAll('[data-tooltip]')) new Foundation.Tooltip($(element));
  DataCycle.htmlObserver.addCallbacks.push([e => 'tooltip' in e.dataset, e => new Foundation.Tooltip($(e))]);

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
