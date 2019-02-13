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
};
