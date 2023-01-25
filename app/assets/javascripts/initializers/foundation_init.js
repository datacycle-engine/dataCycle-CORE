import domElementHelpers from '../helpers/dom_element_helpers';

import { Foundation } from 'foundation-sites/js/foundation.core';
import { Reveal } from 'foundation-sites/js/foundation.reveal';
import { Dropdown } from 'foundation-sites/js/foundation.dropdown';
import { Accordion } from 'foundation-sites/js/foundation.accordion';
import { Slider } from 'foundation-sites/js/foundation.slider';
import { OffCanvas } from 'foundation-sites/js/foundation.offcanvas';
import { Tabs } from 'foundation-sites/js/foundation.tabs';

function removeFoundationOverlays(element, type) {
  let overlay = document.getElementById(element.dataset[type]);
  if (!overlay || document.querySelector(`[data-${type}="${overlay.id}"]`)) return;
  if (overlay.parentElement.classList.contains('reveal-overlay')) overlay = overlay.parentElement;

  overlay.remove();
}

function initReveal(element) {
  if (element.classList.contains('media-preview') && element.closest('.object-browser-overlay')) return;

  element.classList.add('dcjs-foundation-reveal');
  new Foundation.Reveal($(element));

  if (element.dataset.initialState == 'open') $(element).foundation('open');
}

function monitorSizeChanges(element) {
  const resizeObserver = new ResizeObserver(_ => {
    if (domElementHelpers.isVisible(element)) $(element).foundation('_updatePosition');
  });

  resizeObserver.observe(element);
}

export default function () {
  Foundation.addToJquery($);

  Foundation.plugin(Accordion, 'Accordion');
  Foundation.plugin(Dropdown, 'Dropdown');
  Foundation.plugin(OffCanvas, 'OffCanvas');
  Foundation.plugin(Reveal, 'Reveal');
  Foundation.plugin(Slider, 'Slider');
  Foundation.plugin(Tabs, 'Tabs');

  Foundation.Reveal.defaults.closeOnClick = false;
  Foundation.Reveal.defaults.multipleOpened = true;
  Foundation.Dropdown.defaults.position = 'bottom';
  Foundation.Dropdown.defaults.alignment = 'left';
  Foundation.Dropdown.defaults.hover = true;
  Foundation.Dropdown.defaults.hoverPane = true;

  DataCycle.htmlObserver.removeCallbacks.push(['[data-open]', e => removeFoundationOverlays(e, 'open')]);
  DataCycle.htmlObserver.removeCallbacks.push(['[data-toggle]', e => removeFoundationOverlays(e, 'toggle')]);

  // Foundation Slider
  DataCycle.initNewElements('.slider', e => new Foundation.Slider($(e)));

  // Foundation Accordion
  DataCycle.initNewElements('[data-accordion]:not(.dc-fd-accordion)', e => {
    new Foundation.Accordion($(e));
    e.classList.add('dc-fd-accordion');
  });
  DataCycle.initNewElements('[data-accordion].dc-fd-accordion .accordion-item', e =>
    Foundation.reInit($(e.closest('[data-accordion]')))
  );

  // Foundation Dropdown
  DataCycle.initNewElements('[data-dropdown]', e => new Foundation.Dropdown($(e)));

  // Foundation OffCanvas
  DataCycle.initNewElements('[data-off-canvas]', e => new Foundation.OffCanvas($(e)));

  // Foundation Reveal
  DataCycle.initNewElements('[data-reveal]:not(.dcjs-foundation-reveal)', e => initReveal(e));

  // Foundation Reveal Position Updater
  DataCycle.initNewElements('.reveal:not(.full)[data-v-offset="auto"], .reveal:not(.full):not([data-v-offset])', e =>
    monitorSizeChanges(e)
  );

  // Foundation Tabs
  DataCycle.initNewElements('[data-tabs]', e => new Foundation.Tabs($(e)));

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

  $(document).on('click', 'div.accordion-title', event => {
    if ($(event.target).closest('a').length) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    $(event.currentTarget)
      .closest('[data-accordion]')
      .foundation('toggle', $(event.currentTarget).closest('.accordion-title').siblings('.accordion-content'));
  });
}
