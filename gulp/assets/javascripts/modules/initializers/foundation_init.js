// Initialize Foundation for all elements
var foundation = require('foundation-sites');

module.exports.initialize = function() {
  Foundation.Tooltip.defaults.clickOpen = false;
  $(document).foundation();

  $(document).on('changed.dc.html', '*', event => {
    $(event.target).foundation();
  });

  $(document).on('open.zf.reveal', '.reveal', event => {
    if ($(event.target).parent('.reveal-overlay').length)
      $(event.target)
        .parent('.reveal-overlay')
        .appendTo('body');
    else $(event.target).appendTo('body');
  });

  $(document).on('remove', '*', event => {
    event.stopPropagation();
  });

  $(document).on('remove.dc.html', '*', event => {
    event.stopPropagation();

    $(event.target)
      .find('[data-open]')
      .each((i, elem) => {
        if ($('#' + $(elem).data('open')).parent('.reveal-overlay').length)
          $('#' + $(elem).data('open'))
            .parent('.reveal-overlay')
            .trigger('remove.dc.html')
            .remove();
        else
          $('#' + $(elem).data('open'))
            .trigger('remove.dc.html')
            .remove();
      });
    $(event.target)
      .find('[data-toggle]')
      .each((i, elem) => {
        if ($('#' + $(elem).data('toggle')).parent('.reveal-overlay').length)
          $('#' + $(elem).data('toggle'))
            .parent('.reveal-overlay')
            .trigger('remove.dc.html')
            .remove();
        else
          $('#' + $(elem).data('toggle'))
            .trigger('remove.dc.html')
            .remove();
      });
  });
};
