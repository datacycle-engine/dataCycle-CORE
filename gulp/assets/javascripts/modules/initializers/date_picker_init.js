var flatpickr = require('flatpickr');
var Deutsch = require("flatpickr/dist/l10n/de.js").de;
flatpickr.localize(Deutsch);

// Reveal Blur 
module.exports.initialize = function () {

  function init($element) {
    $($element).find('input[type=datetime-local]').each(function () {
      $(this).flatpickr({
        altFormat: "d.m.Y H:i",
        enableTime: true,
        altInput: true,
        time_24hr: true,
        allowInput: true,
        static: true
      });

      var input = $(this).next('input');
      $(input).on('change', function (e) {
        cal.setDate($(this).val(), false, cal.config.altFormat);
        cal.close();
      });
    });

    $($element).find('input[type=date]').each(function () {
      var cal = $(this).flatpickr({
        altFormat: "d.m.Y",
        altInput: true,
        time_24hr: true,
        allowInput: true,
        static: true
      });

      var input = $(this).next('input');
      $(input).on('change', function (e) {
        cal.setDate($(this).val(), false, cal.config.altFormat);
        cal.close();
      });

    });
  }

  init(document)

  $(document).on('clone-added', '.content-object-item', function () {
    init(this);
  });

};