import Flatpickr from 'flatpickr';
import { German } from 'flatpickr/dist/l10n/de.js';
import { english } from 'flatpickr/dist/l10n/default';
import domElementHelpers from '../helpers/dom_element_helpers';
import castArray from 'lodash/castArray';

class DatePicker {
  constructor(element) {
    this.element = element;
    this.elementName = this.element.getAttribute('name');
    this.calType = 'single';
    this.sibling;
    this.calInstance;
    this.conditionalFormField = this.element.closest('.conditional-form-field');
    this.localeMapping = {
      de: German,
      en: english
    };
    this.defaultOptions = {
      locale: this.localeMapping[DataCycle.uiLocale],
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
    this.eventHandlers = {
      change: this.updateDatePicker.bind(this),
      reInit: this.reInit.bind(this),
      setDate: this.setDate.bind(this),
      import: this.importData.bind(this)
    };

    this.setup();
  }
  setup() {
    this.setupCache();
    this.setCalType();
    this.findSibling();
    this.initCalInstance();
  }
  initEvents() {
    $(this.calInstance.altInput).on('change', this.eventHandlers.change);
    $(this.calInstance.altInput).on('dc:flatpickr:reInit', this.eventHandlers.reInit);
    $(this.calInstance.altInput).on('dc:flatpickr:setDate', this.eventHandlers.setDate);
    $(this.calInstance.altInput).on('dc:import:data', this.eventHandlers.import).addClass('dc-import-data');
  }
  removeEvents() {
    $(this.calInstance.altInput).off('change', this.eventHandlers.change);
    $(this.calInstance.altInput).off('dc:flatpickr:reInit', this.eventHandlers.reInit);
    $(this.calInstance.altInput).off('dc:flatpickr:setDate', this.eventHandlers.setDate);
    $(this.calInstance.altInput).off('dc:import:data', this.eventHandlers.import).removeClass('dc-import-data');
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
    const promise = DataCycle.httpRequest({
      url: '/holidays',
      method: 'GET',
      data: {
        year: year
      },
      dataType: 'json',
      contentType: 'application/json'
    });

    promise
      .then(data => {
        DataCycle.cache.holidays[year] = data || [];
      })
      .finally(() => {
        DataCycle.cache.holidays.loadingHolidays[year] = false;
        DataCycle.cache.holidays.loadingHolidaysRequest[year] = null;
      });

    DataCycle.cache.holidays.loadingHolidaysRequest[year] = promise;
  }
  createDayElement(_dObj, _dStr, _fp, dayElem) {
    if (dayElem.classList.contains('dc-holidays-initialized')) return;

    const year = dayElem.dateObj.getFullYear();

    if (!DataCycle.cache.holidays[year] && !DataCycle.cache.holidays.loadingHolidays[year]) this.loadHolidays(year);

    this.markHoliday(dayElem, year);
    dayElem.classList.add('dc-holidays-initialized');
  }
  markHoliday(dayElem, year) {
    if (!DataCycle.cache.holidays[year] && DataCycle.cache.holidays.loadingHolidays[year]) {
      const promise = DataCycle.cache.holidays.loadingHolidaysRequest[year];
      promise.then(_ => this.markHoliday(dayElem, year));

      return promise;
    }

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
  async importData(event, data) {
    event.stopImmediatePropagation();

    if (this.calInstance.altInput.value.length === 0 || (data && data.force)) {
      this.setDate(null, data.value);
      this.updateConditionalField(data.value);
    } else {
      const target = event.currentTarget;

      domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => {
        this.setDate(null, data.value);
        this.updateConditionalField(data.value);
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
