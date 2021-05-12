import Flatpickr from 'flatpickr';
import { German } from 'flatpickr/dist/l10n/de.js';
import ConfirmationModal from './../components/confirmation_modal';
import DataCycle from './data_cycle';

class DatePicker {
  constructor(element, additionalOptions = {}) {
    this.element = element;
    this.elementName = this.element.getAttribute('name');
    this.calType = 'single';
    this.sibling;
    this.calInstance;
    this.conditionalFormField = this.element.closest('.conditional-form-field');
    this.defaultOptions = {
      locale: German,
      altFormat: 'd.m.Y',
      enableTime: false,
      altInput: true,
      time_24hr: true,
      allowInput: true,
      static: true,
      altInputClass: 'flatpickr-input',
      onClose: this.updateSibling.bind(this),
      onDayCreate: this.createDayElement.bind(this)
    };
    this.defaultTimeOptions = {
      altFormat: 'd.m.Y H:i',
      enableTime: true
    };
    this.additionalOptions = additionalOptions;
    this.startKeys = {
      _from: '_until',
      _start: '_end',
      start_time: 'end_time'
    };
    this.endKeys = {
      _until: '_from',
      _end: '_start',
      end_time: 'start_time'
    };
    this.keyMappings = Object.assign({}, this.startKeys, this.endKeys);
    this.keyRegExp = new RegExp(`(${Object.keys(this.keyMappings).join('|')})`, 'gi');

    this.setup();
  }
  setup() {
    this.setupCache();
    this.setCalType();
    this.findSibling();
    this.initCalInstance();

    $(this.calInstance.altInput).on('change', this.updateDatePicker.bind(this));
    $(this.calInstance.altInput).on('dc:date:destroy', this.destroyDatePicker.bind(this));
    $(this.calInstance.altInput).on('dc:flatpickr:setDate', this.setDate.bind(this));
    $(this.calInstance.altInput).on('dc:import:data', this.importData.bind(this));
  }
  setupCache() {
    if (!DataCycle.cache.holidays) {
      DataCycle.cache['holidays'] = {
        loadingHolidays: false,
        loadingHolidaysRequest: null
      };
    }
  }
  initCalInstance() {
    this.calInstance = Flatpickr(this.element, this.options());

    console.log('initCalInstance', this.calInstance, this.element._flatpickr);

    this.updateSibling(null, this.calInstance.altInput.value, null);
  }
  setCalType() {
    if (this.elementName.match(new RegExp(`(${Object.keys(this.startKeys).join('|')})`, 'gi'))) this.calType = 'start';
    if (this.elementName.match(new RegExp(`(${Object.keys(this.endKeys).join('|')})`, 'gi'))) this.calType = 'end';
  }
  updateDatePicker(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.calInstance.setDate(this.calInstance.altInput.value, true, this.calInstance.config.altFormat);
    this.calInstance.close();
  }
  destroyDatePicker(event) {
    event.preventDefault();

    this.calInstance.destroy();
  }
  setDate(event, value) {
    if (event) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }

    this.calInstance.setDate(value, true);
    this.calInstance.close();
  }
  findSibling() {
    const siblingName = this.elementName.replace(this.keyRegExp, m => this.keyMappings[m]);
    this.sibling = document.getElementsByName(siblingName)[0];
  }
  updateSibling(_selectedDates, dateStr, _instance) {
    if (this.calType == 'single' || !this.sibling || !this.sibling._flatpickr) return;

    console.log('updateSibling', dateStr, this.sibling._flatpickr);

    this.sibling._flatpickr.set(this.calType == 'start' ? 'minDate' : 'maxDate', dateStr);
  }
  loadHolidays(year) {
    if (DataCycle.cache.holidays[year]) return;

    DataCycle.cache.holidays.loadingHolidays = true;
    DataCycle.cache.holidays.loadingHolidaysRequest = DataCycle.httpRequest({
      url: '/holidays',
      method: 'GET',
      data: {
        year: year
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .done(data => {
        DataCycle.cache.holidays[year] = data || [];
      })
      .always(_ => {
        DataCycle.cache.holidays.loadingHolidays = false;
        DataCycle.cache.holidays.loadingHolidaysRequest = null;
      });
  }
  createDayElement(_dObj, _dStr, _fp, dayElem) {
    if (dayElem.classList.contains('dc-holidays-initialized')) return;

    if (!DataCycle.cache.holidays[dayElem.dateObj.getFullYear()] && !DataCycle.cache.holidays.loadingHolidays)
      this.loadHolidays(dayElem.dateObj.getFullYear());

    if (!DataCycle.cache.holidays[dayElem.dateObj.getFullYear()] && DataCycle.cache.holidays.loadingHolidays)
      DataCycle.cache.holidays.loadingHolidaysRequest.done(_ => this.markHoliday(dayElem));
    else this.markHoliday(dayElem);

    dayElem.classList.add('dc-holidays-initialized');
  }
  markHoliday(dayElem) {
    const holiday = DataCycle.cache.holidays[dayElem.dateObj.getFullYear()].find(
      v => v.date === this.toLocaleDateString(dayElem.dateObj)
    );

    if (holiday) {
      dayElem.classList.add('holiday');
      dayElem.title = holiday.name;
    }
  }
  toLocaleDateString(dateObject) {
    return `${dateObject.getFullYear()}-${(dateObject.getMonth() + 1).toString().padStart(2, '0')}-${dateObject
      .getDate()
      .toString()
      .padStart(2, '0')}`;
  }
  options() {
    let options = this.defaultOptions;

    if (this.element.getAttribute('type') == 'datetime-local' && this.element.dataset.disableTime != 'true')
      Object.assign(options, this.defaultTimeOptions);

    if (this.additionalOptions && this.additionalOptions.enableTime) Object.assign(options, this.defaultTimeOptions);

    return options;
  }
  importData(event, data) {
    event.stopImmediatePropagation();

    if (!this.conditionalFormField) return;

    if (this.calInstance.altInput.value.length === 0 || (data && data.force)) {
      this.setDate(null, data.value);
      this.updateConditionalField(data.value);
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: () => {
          this.setDate(null, data.value);
          this.updateConditionalField(data.value);
        }
      });
    }
  }
  updateConditionalField(value) {
    $(this.conditionalFormField).trigger('dc:conditionalField:refresh', {
      value:
        (value && value.length) ||
        $(this.conditionalFormField)
          .find('.conditional-field-content :input')
          .serializeArray()
          .filter(v => v && v.value && v.value.trim().length).length
    });
  }
}

export default DatePicker;
