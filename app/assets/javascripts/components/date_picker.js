import Flatpickr from 'flatpickr';
import { German } from 'flatpickr/dist/l10n/de.js';
import { english } from 'flatpickr/dist/l10n/default';
import domElementHelpers from '../helpers/dom_element_helpers';
import castArray from 'lodash/castArray';
import LocalStorageCache from './local_storage_cache';

class DatePicker {
  constructor(element) {
    element.dcDatePicker = true;
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
      opens: 'closes',
      min: 'max'
    };
    this.endKeys = {
      _through: 'from',
      until: 'from',
      _end: '_start',
      end_time: 'start_time',
      closes: 'opens',
      max: 'min'
    };
    this.keyMappings = Object.assign({}, this.startKeys, this.endKeys);
    this.keyRegExp = new RegExp(`(${Object.keys(this.keyMappings).join('|')})`, 'gi');
    this.eventHandlers = {
      change: this.updateDatePicker.bind(this),
      reInit: this.reInit.bind(this),
      setDate: this.setDate.bind(this),
      import: this.importData.bind(this),
      fixTimeElementValueUpdate: this.fixTimeElementValueUpdate.bind(this)
    };
    this.cacheNamespace = 'dcDatepickerCache';

    this.setup();
  }
  setup() {
    this.setCalType();
    this.findSibling();
    this.initCalInstance();
  }
  initEvents() {
    if (this.calInstance.hourElement)
      this.calInstance.hourElement.addEventListener('input', this.eventHandlers.fixTimeElementValueUpdate);
    if (this.calInstance.minuteElement)
      this.calInstance.minuteElement.addEventListener('input', this.eventHandlers.fixTimeElementValueUpdate);

    $(this.calInstance.altInput).on('change', this.eventHandlers.change);
    $(this.calInstance.altInput).on('dc:flatpickr:reInit', this.eventHandlers.reInit);
    $(this.calInstance.altInput).on('dc:flatpickr:setDate', this.eventHandlers.setDate);
    $(this.calInstance.altInput).on('dc:import:data', this.eventHandlers.import).addClass('dc-import-data');
  }
  removeEvents() {
    if (this.calInstance.hourElement)
      this.calInstance.hourElement.removeEventListener('input', this.eventHandlers.fixTimeElementValueUpdate);
    if (this.calInstance.minuteElement)
      this.calInstance.minuteElement.removeEventListener('input', this.eventHandlers.fixTimeElementValueUpdate);

    $(this.calInstance.altInput).off('change', this.eventHandlers.change);
    $(this.calInstance.altInput).off('dc:flatpickr:reInit', this.eventHandlers.reInit);
    $(this.calInstance.altInput).off('dc:flatpickr:setDate', this.eventHandlers.setDate);
    $(this.calInstance.altInput).off('dc:import:data', this.eventHandlers.import).removeClass('dc-import-data');
  }
  fixTimeElementValueUpdate(event) {
    event.target.blur();
    event.target.focus();

    const { value } = event.target;

    event.target.value = '';
    event.target.value = value;
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
  async loadHolidays(year) {
    const promise = DataCycle.httpRequest({
      url: '/holidays',
      method: 'GET',
      data: {
        year: year
      },
      dataType: 'json',
      contentType: 'application/json'
    });

    const promiseKey = `${this.cacheNamespace}/${year}`;
    DataCycle.globalPromises[promiseKey] = promise;

    const holidays = (await promise) || [];

    LocalStorageCache.set(this.cacheNamespace, year, holidays);
    delete DataCycle.globalPromises[promiseKey];

    return holidays;
  }
  async createDayElement(_dObj, _dStr, _fp, dayElem) {
    if (dayElem.classList.contains('dc-holidays-initialized')) return;

    await this.markHoliday(dayElem, dayElem.dateObj.getFullYear());
    dayElem.classList.add('dc-holidays-initialized');
  }
  async markHoliday(dayElem, year) {
    const promiseKey = `${this.cacheNamespace}/${year}`;
    let holidays = LocalStorageCache.get(this.cacheNamespace, year);
    if (!holidays && DataCycle.globalPromises.hasOwnProperty(promiseKey))
      holidays = await DataCycle.globalPromises[promiseKey];
    else if (!holidays) holidays = await this.loadHolidays(year);

    const holiday = holidays.find(v => v.date === Flatpickr.formatDate(dayElem.dateObj, 'Y-m-d'));

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
