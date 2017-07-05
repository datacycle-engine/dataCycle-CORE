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
    $(this).flatpickr({
      altFormat: "d.m.Y",
      altInput: true,
      time_24hr: true,
      allowInput: true
    });
  });

};