// Initialize Foundation for all elements
var foundation = require('foundation-sites');

module.exports.initialize = function ($) {
  Foundation.Tooltip.defaults.clickOpen = false;
  Foundation.Reveal.defaults.closeOnClick = false;
  Foundation.Reveal.defaults.multipleOpened = true;
  $('body').foundation().addClass('dc-fd-initialized');

  $(document).on('dc:html:changed dc:contents:added', '*:not(.dc-fd-initialized)', event => {
    event.stopPropagation();

    if ($(event.target).hasClass('accordion-item')) Foundation.reInit($(event.target).closest('[data-accordion]'));
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
};
