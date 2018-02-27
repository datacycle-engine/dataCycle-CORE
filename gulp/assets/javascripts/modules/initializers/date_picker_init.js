var flatpickr = require('flatpickr');
var Deutsch = require("flatpickr/dist/l10n/de.js").de;
flatpickr.localize(Deutsch);

module.exports.initialize = function () {
  //  TODO: dont fire change event on setup/setSibling
  var calenders = [];

  function init($element) {
    let new_cals = [];
    $($element).find('input[type=datetime-local]').each(function () {
      if (!$(this).attr('readonly')) {
        var cal = $(this).flatpickr({
          altFormat: "d.m.Y H:i",
          enableTime: true,
          altInput: true,
          time_24hr: true,
          allowInput: true,
          static: true,
          onClose: setSibling
        });

        new_cals.push(cal);
        var input = $(this).next('input');
        $(input).on('change', function (e) {
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          cal.setDate($(this).val(), true, cal.config.altFormat);
          cal.close();
        });
      }
    });

    $($element).find('input[type=date]').each(function () {
      if (!$(this).attr('readonly')) {
        var cal = $(this).flatpickr({
          altFormat: "d.m.Y",
          altInput: true,
          time_24hr: true,
          allowInput: true,
          static: true,
          onClose: setSibling
        });

        new_cals.push(cal);
        var input = $(this).next('input');
        $(input).on('change', function (e) {
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          cal.setDate($(this).val(), true, cal.config.altFormat);
          cal.close();
        });
      }
    });

    setup(new_cals);
    calenders = calenders.concat(new_cals);
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

  function setup(cals) {
    for (var i = 0; i < cals.length; i++) {
      var siblings = cals.filter(function (val) {
        return getIdFromCalender(val) == getIdFromCalender(cals[i]);
      });

      if (siblings.length == 2) {
        siblings[0].set("maxDate", siblings[1].input.value);
        siblings[1].set("minDate", siblings[0].input.value);
      }
      i++;
    }

  }

  function getIdFromCalender(instance) {
    var ignore = ['from', 'until', 'start', 'end'];
    var id = instance.element.id.split('_');
    id = id.filter(function (val) {
      return ignore.indexOf(val) == -1;
    });

    id = id.join('_');

    return id;
  }
};
