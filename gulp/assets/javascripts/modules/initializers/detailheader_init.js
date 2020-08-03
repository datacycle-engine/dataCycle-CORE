// Reveal Blur
module.exports.initialize = function ($) {
  $(document).on('click', '.copy-to-clipboard', function (event) {
    event.preventDefault();
    var text = $(this).data('value');
    var inp = document.createElement('input');
    document.body.appendChild(inp);
    inp.value = text;
    inp.select();
    document.execCommand('copy', false);
    inp.remove();

    $(this).before('<span class="clipboard-notice">In Zwischenablage kopiert.</span>');
    setTimeout(
      function () {
        $(this)
          .siblings('.clipboard-notice')
          .fadeOut('fast', function () {
            $(this).remove();
          });
      }.bind(this),
      1000
    );
  });

  $(document).on('click', '.show-more .show-more-link', event => {
    event.preventDefault();

    $(event.currentTarget)
      .parent('.show-more')
      .toggleClass('active')
      .get(0)
      .scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  });

  $(document).on('click', '.toggler', event => {
    event.preventDefault();

    $(event.currentTarget).toggleClass('active');

    $('#' + $(event.currentTarget).data('toggle'))
      .toggleClass('active')
      .trigger('dc:toggler:show')
      .get(0)
      .scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  });
};
