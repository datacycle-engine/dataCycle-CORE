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
        onChange: setSibling,
        onReady: setup
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
        static: true,
        onChange: setSibling,
        onReady: setup
      });

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
    if (calenders.indexOf(instance) >= 0) {
      var siblings = calenders.filter(function (val) {
        return getIdFromCalender(val) == getIdFromCalender(instance);
      });

      if (siblings.length == 2 && instance == siblings[0]) siblings[1].set("minDate", dateStr);
      if (siblings.length == 2 && instance == siblings[1]) siblings[0].set("maxDate", dateStr);
    }
  }

  function setup(selectedDates, dateStr, instance) {
    if (calenders.indexOf(instance) < 0) calenders.push(instance);

    var siblings = calenders.filter(function (val) {
      return getIdFromCalender(val) == getIdFromCalender(instance);
    });

    if (siblings.length == 2) {
      if (instance == siblings[0]) {
        siblings[0].set("maxDate", siblings[1].input.value);
        siblings[1].set("minDate", dateStr);
      } else if (instance == siblings[1]) {
        siblings[0].set("maxDate", dateStr);
        siblings[1].set("minDate", siblings[0].input.value);
      }
    }
  }

  function getIdFromCalender(instance) {
    var id = instance.element.id.split('_');
    id.pop();
    id = id.join('_');

    return id;
  }
};