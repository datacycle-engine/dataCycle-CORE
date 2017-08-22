var flatpickr = require('flatpickr');
var Deutsch = require("flatpickr/dist/l10n/de.js").de;
flatpickr.localize(Deutsch);

// Reveal Blur
module.exports.initialize = function () {

  var calenders = [];

  function init($element) {
    $($element).find('input[type=datetime-local]').each(function () {
      var cal = $(this).flatpickr({
        altFormat: "d.m.Y H:i",
        enableTime: true,
        altInput: true,
        time_24hr: true,
        allowInput: true,
        static: true,
        onChange: setSibling
      });
      calenders.push(cal);

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
        static: true,
        onChange: setSibling
      });
      calenders.push(cal);

      var input = $(this).next('input');
      $(input).on('change', function (e) {
        cal.setDate($(this).val(), true, cal.config.altFormat);
        cal.close();
      });

    });

  }

  init(document)

  $(document).on('clone-added', '.content-object-item', function () {
    init(this);
  });

  function setSibling(selectedDates, dateStr, instance) {
    var index = calenders.indexOf(instance);
    if (index >= 0) {
      var id = instance.element.id;
      id = id.split('_');
      id.pop();
      id = id.join('_');

      var until_cal = calenders.filter(function (val) {
        temp_id = val.element.id.split('_');
        temp_id.pop();
        temp_id = temp_id.join('_');
        return temp_id == id;
      });

      if (until_cal.length == 2 && instance == until_cal[0]) until_cal[1].set("minDate", dateStr);
      if (until_cal.length == 2 && instance == until_cal[1]) until_cal[0].set("maxDate", dateStr);
    }
  };
};