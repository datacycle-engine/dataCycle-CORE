import Flatpickr from 'flatpickr';
import { German } from 'flatpickr/dist/l10n/de.js';
import ConfirmationModal from './../components/confirmation_modal';
import DataCycle from './data_cycle';
import castArray from 'lodash/castArray';

class DatePicker {
  constructor(element) {
    this.element = element;
    this.elementName = this.element.getAttribute('name');
    this.calType = 'single';
    this.sibling;
    this.calInstance;
    this.conditionalFormField = this.element.closest('.conditional-form-field');
    this.defaultOptions = {
      locale: German,
      altInput: true,
      time_24hr: true,
      allowInput: true,
      static: true,
      altFormat: 'd.m.Y',
      enableTime: false,
      altInputClass: 'flatpickr-input',
      onClose: this.updateSibling.bind(this),
      onDayCreate: this.createDayElement.bind(this)
    };
    this.dateTimeOptions = {
      altFormat: 'd.m.Y H:i',
      enableTime: true
    };
    this.timeOptions = {
      enableTime: true,
      noCalendar: true,
      dateFormat: 'H:i',
      altFormat: 'H:i',
      onClose: null,
      onDayCreate: null
    };
    this.configs = {};
    this.startKeys = {
      from: ['until', '_through'],
      _start: '_end',
      start_time: 'end_time',
      opens: 'closes'
    };
    this.endKeys = {
      _through: 'from',
      until: 'from',
      _end: '_start',
      end_time: 'start_time',
      closes: 'opens'
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
  }
  initEvents() {
    $(this.calInstance.altInput).on('change', this.updateDatePicker.bind(this));
    $(this.calInstance.altInput).on('dc:flatpickr:reInit', this.reInit.bind(this));
    $(this.calInstance.altInput).on('dc:flatpickr:setDate', this.setDate.bind(this));
    $(this.calInstance.altInput).on('dc:import:data', this.importData.bind(this));
  }
  removeEvents() {
    $(this.calInstance.altInput).off('change', this.updateDatePicker.bind(this));
    $(this.calInstance.altInput).off('dc:flatpickr:reInit', this.reInit.bind(this));
    $(this.calInstance.altInput).off('dc:flatpickr:setDate', this.setDate.bind(this));
    $(this.calInstance.altInput).off('dc:import:data', this.importData.bind(this));
  }
  setupCache() {
    if (!DataCycle.cache.holidays) {
      DataCycle.cache['holidays'] = {
        loadingHolidays: {},
        loadingHolidaysRequest: {}
      };
    }
  }
  initCalInstance() {
    this.calInstance = Flatpickr(this.element, this.options());

    if (this.element.dataset.type != 'timepicker') this.getLimitFromSibling();

    this.initEvents();
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
  destroy() {
    this.removeEvents();
    this.calInstance.destroy();
  }
  reInit(event, configs) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.configs = configs || {};

    this.destroy();
    this.initCalInstance();
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
    const foundMatch = this.elementName.match(this.keyRegExp);
    this.sibling = castArray(this.keyMappings[foundMatch]).reduce(
      (a, v) => a || document.getElementsByName(this.elementName.replace(foundMatch, v))[0],
      null
    );
  }
  updateSibling(_selectedDates, dateStr, _instance) {
    if (this.calType == 'single' || !this.sibling || !this.sibling._flatpickr) return;

    this.sibling._flatpickr.set(this.calType == 'start' ? 'minDate' : 'maxDate', dateStr);
  }
  getLimitFromSibling() {
    if (this.calType == 'single' || !this.sibling) return;

    this.calInstance.set(this.calType == 'start' ? 'maxDate' : 'minDate', this.sibling.value);
  }
  loadHolidays(year) {
    if (DataCycle.cache.holidays[year]) return;

    DataCycle.cache.holidays.loadingHolidays[year] = true;
    DataCycle.cache.holidays.loadingHolidaysRequest[year] = DataCycle.httpRequest({
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
        DataCycle.cache.holidays.loadingHolidays[year] = false;
        DataCycle.cache.holidays.loadingHolidaysRequest[year] = null;
      });
  }
  createDayElement(_dObj, _dStr, _fp, dayElem) {
    if (dayElem.classList.contains('dc-holidays-initialized')) return;

    const year = dayElem.dateObj.getFullYear();

    if (!DataCycle.cache.holidays[year] && !DataCycle.cache.holidays.loadingHolidays[year]) this.loadHolidays(year);

    this.markHoliday(dayElem, year);
    dayElem.classList.add('dc-holidays-initialized');
  }
  markHoliday(dayElem, year) {
    if (!DataCycle.cache.holidays[year] && DataCycle.cache.holidays.loadingHolidays[year])
      return DataCycle.cache.holidays.loadingHolidaysRequest[year].done(_ => this.markHoliday(dayElem, year));

    const holiday = DataCycle.cache.holidays[year].find(v => v.date === Flatpickr.formatDate(dayElem.dateObj, 'Y-m-d'));

    if (holiday) {
      dayElem.classList.add('holiday');
      dayElem.title = holiday.name;
    }
  }
  options() {
    let options = Object.assign({}, this.defaultOptions);

    if (
      (this.element.getAttribute('type') == 'datetime-local' && this.element.dataset.disableTime != 'true') ||
      (this.configs && this.configs.enableTime)
    )
      Object.assign(options, this.dateTimeOptions);

    if (this.element.dataset.type == 'timepicker') Object.assign(options, this.timeOptions);

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
