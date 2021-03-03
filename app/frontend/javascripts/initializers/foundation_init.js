// Initialize Foundation for all elements
import Foundation from 'foundation-sites';

export default function () {
  Foundation.Tooltip.defaults.clickOpen = false;
  Foundation.Reveal.defaults.closeOnClick = false;
  Foundation.Reveal.defaults.multipleOpened = true;
  $('body').foundation().addClass('dc-fd-initialized');

  $(document).on('dc:html:changed dc:contents:added', '*:not(.dc-fd-initialized)', event => {
    event.stopPropagation();

    if ($(event.target).hasClass('accordion-item')) Foundation.reInit($(event.target).closest('[data-accordion]'));
    if ($(event.target).hasClass('accordion')) Foundation.reInit($(event.target));
    $(event.target).foundation().addClass('dc-fd-initialized');
  });

  $(document).on('open.zf.reveal', '.reveal', event => {
    event.stopPropagation();
    $('.reveal:visible, .reveal-overlay:visible').css('z-index', '');
    $(event.target).add($(event.target).parent('.reveal-overlay')).css('z-index', 1007);
  });

  $(document).on('closed.zf.reveal', '.reveal', event => {
    event.stopPropagation();
    if ($(event.target).find('video').length) $(event.target).find('video').get(0).pause();
  });

  $(document).on('remove', '*', event => {
    event.stopPropagation();
  });

  $(document).on('dc:html:remove', '*', event => {
    event.stopPropagation();

    $(event.target)
      .find('[data-open]')
      .each((i, elem) => {
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
    $(event.target)
      .find('[data-toggle]')
      .each((i, elem) => {
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
