var flatpickr = require('flatpickr');

// Reveal Blur 
module.exports.initialize = function () {

  $('input[type=date]').each(function () {
    $(this).flatpickr({
      altFormat: "d.m.Y",
      altInput: true,
      time_24hr: true,
      allowInput: true
    });
  });

};