import Flatpickr from 'flatpickr';
import { German } from 'flatpickr/dist/l10n/de.js';
import ConfirmationModal from './../components/confirmation_modal';

export default function () {
  var calenders = [];

  let flatPickrOptions = {
    locale: German,
    altFormat: 'd.m.Y',
    enableTime: false,
    altInput: true,
    time_24hr: true,
    allowInput: true,
    static: true,
    altInputClass: 'flatpickr-input',
    onClose: setSibling
  };

  let flatPickrTimeOptions = {
    altFormat: 'd.m.Y H:i',
    enableTime: true
  };

  init(document);

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  $(document).on('dc:date:initialize', '*', (event, data) => {
    event.stopPropagation();
    reInit(event.target, data);
  });

  $(document).on('dc:import:data', '.form-element.datetime input.flatpickr-input', (event, data) => {
    event.stopImmediatePropagation();
    const $element = $(event.currentTarget);
    const $conditionalFormField = $element.closest('.conditional-form-field');

    if ($element.val().length === 0 || (data && data.force)) {
      $element.trigger('dc:flatpickr:setDate', data.value);
      updateConditionalField($conditionalFormField, data.value);
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: () => {
          $element.trigger('dc:flatpickr:setDate', data.value);
          updateConditionalField($conditionalFormField, data.value);
        }
      });
    }
  });

  function updateConditionalField($conditionalFormField, value) {
    if ($conditionalFormField.length) {
      $conditionalFormField.trigger('dc:conditionalField:refresh', {
        value:
          (value && value.length) ||
          $conditionalFormField
            .find('.conditional-field-content :input')
            .serializeArray()
            .filter(v => v && v.value && v.value.trim().length).length
      });
    }
  }

  function removeEventHandlers(event) {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
  }

  function getIdFromCalender(instance) {
    return instance.element.id.replace(/_from|_until|_start|_end/gi, '');
  }

  function setSibling(_selectedDates, dateStr, instance) {
    if (calenders.indexOf(instance) >= 0) {
      var siblings = calenders.filter(function (val) {
        return getIdFromCalender(val) == getIdFromCalender(instance);
      });
      if (siblings.length == 2) {
        $(siblings[0].input).add(siblings[1].input).on('change', removeEventHandlers);
        if (instance == siblings[0]) siblings[1].set('minDate', dateStr);
        if (instance == siblings[1]) siblings[0].set('maxDate', dateStr);
        $(siblings[0].input).add(siblings[1].input).off('change', removeEventHandlers);
      }
    }
  }

  function setup(cals) {
    for (var i = 0; i < cals.length; i++) {
      var siblings = cals.filter(function (val) {
        return getIdFromCalender(val) == getIdFromCalender(cals[i]);
      });

      if (siblings.length == 2) {
        $(siblings[0].input).add(siblings[1].input).on('change', removeEventHandlers);
        siblings[0].set('maxDate', siblings[1].input.value);
        siblings[1].set('minDate', siblings[0].input.value);
        $(siblings[0].input).add(siblings[1].input).off('change', removeEventHandlers);
      }
      i++;
    }
  }

  function init(element) {
    let newCals = [];
    $(element)
      .find('input[type=datetime-local]')
      .each((_, elem) => {
        if (!$(elem).attr('readonly'))
          newCals.push(initDatePicker(elem, $(elem).data('disable-time') ? flatPickrOptions : flatPickrTimeOptions));
      });

    $(element)
      .find('input[type=date]')
      .each((_, elem) => {
        if (!$(elem).attr('readonly')) newCals.push(initDatePicker(elem));
      });

    setup(newCals);
    calenders = calenders.concat(newCals);
  }

  function reInit(element, options = {}) {
    let newCals = [];

    $(element)
      .find('input[data-type=datepicker]')
      .each((_, item) => {
        if (!$(item).attr('readonly'))
          newCals.push(initDatePicker(item, options && options.enableTime ? flatPickrTimeOptions : flatPickrOptions));
      });

    setup(newCals);
    calenders = calenders.concat(newCals);
  }

  function initDatePicker(elem, options = {}) {
    var cal = Flatpickr(elem, Object.assign({}, flatPickrOptions, options));

    var input = $(elem).next('input');
    $(input).on('change', e => {
      e.preventDefault();
      e.stopImmediatePropagation();
      cal.setDate($(e.currentTarget).val(), true, cal.config.altFormat);
      cal.close();
    });

    $(input).on('dc:date:destroy', e => {
      e.preventDefault();

      let container = $(e.currentTarget).closest('.flatpickr-wrapper');
      cal.destroy();
      calenders = calenders.filter(c => c.element != elem);

      container.find(':input').detach().insertBefore(container);
      container.remove();
    });

    $(input).on('dc:flatpickr:setDate', (e, value) => {
      e.preventDefault();
      e.stopImmediatePropagation();
      cal.setDate(value, true);
      cal.close();
    });

    return cal;
  }
}
