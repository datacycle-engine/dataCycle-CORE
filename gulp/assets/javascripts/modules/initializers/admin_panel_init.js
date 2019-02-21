// Reveal Blur
module.exports.initialize = function() {
  $('.copy-to-admin-clipboard').on('click', function(event) {
    event.preventDefault();
    var text = $(this)
      .parent()
      .parent()
      .find('pre code')
      .html();
    var inp = document.createElement('input');
    document.body.appendChild(inp);
    inp.value = text;
    inp.select();
    document.execCommand('copy', false);
    inp.remove();

    $(this).before('<span class="admin-clipboard-notice">In Zwischenablage kopiert.</span>');
    setTimeout(
      function() {
        $(this)
          .siblings('.admin-clipboard-notice')
          .fadeOut('fast', function() {
            $(this).remove();
          });
      }.bind(this),
      1000
    );
  });
};
