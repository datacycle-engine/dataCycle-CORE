var flatpickr = require("flatpickr");
var Deutsch = require("flatpickr/dist/l10n/de.js").default.de;

module.exports.initialize = function () {
  //  TODO: dont fire change event on setup/setSibling
  var calenders = [];

  function init($element) {
    let new_cals = [];
    $($element).find('input[type=datetime-local]').each(function () {
      if (!$(this).attr('readonly')) {
        var cal = $(this).flatpickr({
          locale: Deutsch,
          altFormat: "d.m.Y H:i",
          enableTime: true,
          altInput: true,
          time_24hr: true,
          allowInput: true,
          static: true,
          onClose: set_sibling
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
          locale: Deutsch,
          altFormat: "d.m.Y",
          altInput: true,
          time_24hr: true,
          allowInput: true,
          static: true,
          onClose: set_sibling
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

  function set_sibling(selectedDates, dateStr, instance) {
    if (calenders.indexOf(instance) >= 0) {
      var siblings = calenders.filter(function (val) {
        return get_id_from_calender(val) == get_id_from_calender(instance);
      });
      if (siblings.length == 2) {
        $(siblings[0].input).add(siblings[1].input).on('change', remove_event_handlers);
        if (instance == siblings[0]) siblings[1].set("minDate", dateStr);
        if (instance == siblings[1]) siblings[0].set("maxDate", dateStr);
        $(siblings[0].input).add(siblings[1].input).off('change', remove_event_handlers);
      }
    }
  }

  function setup(cals) {
    for (var i = 0; i < cals.length; i++) {
      var siblings = cals.filter(function (val) {
        return get_id_from_calender(val) == get_id_from_calender(cals[i]);
      });

      if (siblings.length == 2) {
        $(siblings[0].input).add(siblings[1].input).on('change', remove_event_handlers);
        siblings[0].set("maxDate", siblings[1].input.value);
        siblings[1].set("minDate", siblings[0].input.value);
        $(siblings[0].input).add(siblings[1].input).off('change', remove_event_handlers);
      }
      i++;
    }

  }

  function remove_event_handlers(event) {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
  };

  function get_id_from_calender(instance) {
    var ignore = ['from', 'until', 'start', 'end'];
    var id = instance.element.id.split('_');
    id = id.filter(function (val) {
      return ignore.indexOf(val) == -1;
    });

    id = id.join('_');

    return id;
  }
};
