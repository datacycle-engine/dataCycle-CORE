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

};
