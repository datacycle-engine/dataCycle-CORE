var flatpickr = require('flatpickr');
var Deutsch = require('flatpickr/dist/l10n/de.js').default.de;
var ConfirmationModal = require('./../components/confirmation_modal');

module.exports.initialize = function() {
  //  TODO: dont fire change event on setup/setSibling
  var calenders = [];

  let remove_event_handlers = function(event) {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
  };

  let get_id_from_calender = function(instance) {
    return instance.element.id.replace(/_from|_until|_start|_end/gi, '');
  };

  let set_sibling = function(selectedDates, dateStr, instance) {
    if (calenders.indexOf(instance) >= 0) {
      var siblings = calenders.filter(function(val) {
        return get_id_from_calender(val) == get_id_from_calender(instance);
      });
      if (siblings.length == 2) {
        $(siblings[0].input)
          .add(siblings[1].input)
          .on('change', remove_event_handlers);
        if (instance == siblings[0]) siblings[1].set('minDate', dateStr);
        if (instance == siblings[1]) siblings[0].set('maxDate', dateStr);
        $(siblings[0].input)
          .add(siblings[1].input)
          .off('change', remove_event_handlers);
      }
    }
  };

  let setup = function(cals) {
    for (var i = 0; i < cals.length; i++) {
      var siblings = cals.filter(function(val) {
        return get_id_from_calender(val) == get_id_from_calender(cals[i]);
      });

      if (siblings.length == 2) {
        $(siblings[0].input)
          .add(siblings[1].input)
          .on('change', remove_event_handlers);
        siblings[0].set('maxDate', siblings[1].input.value);
        siblings[1].set('minDate', siblings[0].input.value);
        $(siblings[0].input)
          .add(siblings[1].input)
          .off('change', remove_event_handlers);
      }
      i++;
    }
  };

  let init = function($element) {
    let new_cals = [];
    $($element)
      .find('input[type=datetime-local]')
      .each(function() {
        if (!$(this).attr('readonly')) {
          var cal = $(this).flatpickr({
            locale: Deutsch,
            altFormat: 'd.m.Y H:i',
            enableTime: true,
            altInput: true,
            time_24hr: true,
            allowInput: true,
            static: true,
            onClose: set_sibling
          });

          new_cals.push(cal);
          var input = $(this).next('input');
          $(input).on('change', function(e) {
            e.preventDefault();
            e.stopPropagation();
            e.stopImmediatePropagation();
            cal.setDate($(this).val(), true, cal.config.altFormat);
            cal.close();
          });
          $(input).on('dc:flatpickr:setDate', (e, value) => {
            e.preventDefault();
            e.stopImmediatePropagation();
            cal.setDate(value, true);
          });
        }
      });

    $($element)
      .find('input[type=date]')
      .each(function() {
        if (!$(this).attr('readonly')) {
          var cal = $(this).flatpickr({
            locale: Deutsch,
            altFormat: 'd.m.Y',
            altInput: true,
            time_24hr: true,
            allowInput: true,
            static: true,
            onClose: set_sibling
          });

          new_cals.push(cal);
          var input = $(this).next('input');
          $(input).on('change', function(e) {
            e.preventDefault();
            e.stopPropagation();
            e.stopImmediatePropagation();
            cal.setDate($(this).val(), true, cal.config.altFormat);
            cal.close();
          });
          $(input).on('dc:flatpickr:setDate', (e, value) => {
            e.preventDefault();
            e.stopImmediatePropagation();
            cal.setDate(value, true);
          });
        }
      });

    setup(new_cals);
    calenders = calenders.concat(new_cals);
  };

  init(document);

  $(document).on('dc:html:changed', '*', event => {
    init(event.target);
  });

  $(document).on('dc:import:data', '.form-element.datetime input.flatpickr-input', function(event, data) {
    event.stopImmediatePropagation();
    if ($(event.target).val().length === 0 || (data && data.force)) {
      $(event.target).trigger('dc:flatpickr:setDate', data.value);
    } else {
      var confirmationModal = new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function() {
          $(event.target).trigger('dc:flatpickr:setDate', data.value);
        }.bind(this)
      });
    }
  });
};
