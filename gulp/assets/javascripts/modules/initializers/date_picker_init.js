var flatpickr = require('flatpickr');

// Reveal Blur 
module.exports.initialize = function () {

  $('input[type=datetime-local]').each(function () {
    $(this).flatpickr({
      altFormat: "d.m.Y H:i",
      enableTime: true,
      altInput: true,
      time_24hr: true,
      allowInput: true
    });
  });

  $('input[type=date]').each(function () {
    var cal = $(this).flatpickr({
      altFormat: "d.m.Y",
      altInput: true,
      time_24hr: true,
      allowInput: true,
      static: true
    });

    var input = $(this).next('input');
    $(input).on('change', function (e) {
      cal.setDate($(this).val(), false, "d.m.Y");
    });
  });

};