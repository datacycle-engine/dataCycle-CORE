// Reveal Blur
module.exports.initialize = function () {

  $('.copy-to-clipboard').on('click', function (event) {
    event.preventDefault();
    var text = this.href;
    var inp = document.createElement('input');
    document.body.appendChild(inp)
    inp.value = text;
    inp.select();
    document.execCommand('copy', false);
    inp.remove();

    $(this).before('<span class="clipboard-notice">In Zwischenablage kopiert.</span>');
    setTimeout(function () {
      $(this).siblings('.clipboard-notice').fadeOut('fast', function () {
        $(this).remove();
      });
    }.bind(this), 1000);
  });

  // show-more handlers
  if ($('.show-more').length) {
    $('.show-more .show-more-link').on('click', event => {
      $(event.currentTarget).parent('.show-more').toggleClass('active');
      $(event.currentTarget).siblings('.show-more-short').slideToggle(250);
      $(event.currentTarget).siblings('.show-more-long').slideToggle(250);
    });
  }

};
