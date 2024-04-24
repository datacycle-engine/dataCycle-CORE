import Flatpickr from "flatpickr";
import { German } from "flatpickr/dist/l10n/de.js";
import { english } from "flatpickr/dist/l10n/default";
import DomElementHelpers from "../helpers/dom_element_helpers";
import castArray from "lodash/castArray";
import LocalStorageCache from "./local_storage_cache";

class DatePicker {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-date-picker");
		this.elementName = this.element.getAttribute("name");
		this.calType = "single";
		this.sibling;
		this.calInstance;
		this.conditionalFormField = this.element.closest(".conditional-form-field");
		this.localeMapping = {
			de: German,
			en: english,
		};
		this.initialFocus = DomElementHelpers.parseDataAttribute(
			this.element.dataset.initialFocus,
		);
		this.defaultOptions = {
			locale: this.localeMapping[DataCycle.uiLocale],
			altInput: true,
			time_24hr: true,
			allowInput: true,
			static: true,
			altFormat: "d.m.Y",
			enableTime: false,
			altInputClass: "flatpickr-input",
			onClose: this.updateSibling.bind(this),
			onDayCreate: this.createDayElement.bind(this),
		};
		this.dateTimeOptions = {
			altFormat: "d.m.Y H:i",
			enableTime: true,
		};
		this.timeOptions = {
			enableTime: true,
			noCalendar: true,
			dateFormat: "H:i",
			altFormat: "H:i",
			onClose: null,
			onDayCreate: null,
		};
		this.configs = {};
		this.startKeys = {
			from: ["until", "_through"],
			_start: "_end",
			"[start_time][time]": ["[end_time][time]", "[rrules][][until]"],
			start_time: "end_time",
			opens: "closes",
			min: "max",
		};
		this.endKeys = {
			_through: "from",
			"[rrules][][until]": "[start_time][time]",
			"[end_time][time]": "[start_time][time]",
			until: ["from", "start_time"],
			_end: "_start",
			end_time: "start_time",
			closes: "opens",
			max: "min",
		};
		this.keyMappings = Object.assign({}, this.startKeys, this.endKeys);
		this.keyRegExp = this.toRegex(Object.keys(this.keyMappings));
		this.eventHandlers = {
			change: this.updateDatePicker.bind(this),
			reInit: this.reInit.bind(this),
			setDate: this.setDate.bind(this),
			import: this.importData.bind(this),
			fixTimeElementValueUpdate: this.fixTimeElementValueUpdate.bind(this),
			clear: this.clear.bind(this),
		};
		this.cacheNamespace = "dcDatepickerCache";
		this.isDateTime = this.elementIsDateTime(this.element);
		this.element.dataset.isDateTime = this.isDateTime;

		this.setup();
	}
	elementIsDateTime(element) {
		return Object.hasOwn(element.dataset, "isDateTime")
			? DomElementHelpers.parseDataAttribute(element.dataset.isDateTime)
			: element.getAttribute("type") === "datetime-local" &&
					element.dataset.disableTime !== "true";
	}
	setup() {
		this.setCalType();
		this.findSibling();
		this.initCalInstance();
	}
	initEvents() {
		if (this.calInstance.hourElement)
			this.calInstance.hourElement.addEventListener(
				"input",
				this.eventHandlers.fixTimeElementValueUpdate,
			);
		if (this.calInstance.minuteElement)
			this.calInstance.minuteElement.addEventListener(
				"input",
				this.eventHandlers.fixTimeElementValueUpdate,
			);

		$(this.calInstance.altInput).on("change", this.eventHandlers.change);
		$(this.calInstance.altInput).on(
			"dc:flatpickr:reInit",
			this.eventHandlers.reInit,
		);
		$(this.calInstance.altInput).on(
			"dc:flatpickr:setDate",
			this.eventHandlers.setDate,
		);
		$(this.calInstance.altInput)
			.on("dc:import:data", this.eventHandlers.import)
			.addClass("dc-import-data");

		this.calInstance.altInput.addEventListener(
			"clear",
			this.eventHandlers.clear,
		);
	}
	removeEvents() {
		if (this.calInstance.hourElement)
			this.calInstance.hourElement.removeEventListener(
				"input",
				this.eventHandlers.fixTimeElementValueUpdate,
			);
		if (this.calInstance.minuteElement)
			this.calInstance.minuteElement.removeEventListener(
				"input",
				this.eventHandlers.fixTimeElementValueUpdate,
			);

		$(this.calInstance.altInput).off("change", this.eventHandlers.change);
		$(this.calInstance.altInput).off(
			"dc:flatpickr:reInit",
			this.eventHandlers.reInit,
		);
		$(this.calInstance.altInput).off(
			"dc:flatpickr:setDate",
			this.eventHandlers.setDate,
		);
		$(this.calInstance.altInput)
			.off("dc:import:data", this.eventHandlers.import)
			.removeClass("dc-import-data");

		this.calInstance.altInput.removeEventListener(
			"clear",
			this.eventHandlers.clear,
		);
	}
	toRegex(values) {
		if (!values?.length) return;

		return new RegExp(
			`(${values.join("|").replaceAll("[", "\\[").replaceAll("]", "\\]")})`,
			"gi",
		);
	}
	fixTimeElementValueUpdate(event) {
		event.target.blur();
		event.target.focus();

		const { value } = event.target;

		event.target.value = "";
		event.target.value = value;
	}
	initCalInstance() {
		this.calInstance = Flatpickr(this.element, this.options());
		if (this.initialFocus) {
			this.element.removeAttribute("data-initial-focus");
			this.calInstance.altInput.dataset.initialFocus = true;
		}

		if (this.element.dataset.type !== "timepicker") this.getLimitFromSibling();

		this.initEvents();
	}
	setCalType() {
		if (this.elementName.match(this.toRegex(Object.keys(this.startKeys))))
			this.calType = "start";
		if (this.elementName.match(this.toRegex(Object.keys(this.endKeys))))
			this.calType = "end";
	}
	updateDatePicker(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.calInstance.setDate(
			this.calInstance.altInput.value,
			true,
			this.calInstance.config.altFormat,
		);
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
			(a, v) =>
				a ||
				document.getElementsByName(this.elementName.replace(foundMatch, v))[0],
			null,
		);
	}
	updateSibling(_selectedDates, dateStr, _instance) {
		if (this.calType === "single" || !this.sibling || !this.sibling._flatpickr)
			return;

		const option = this.calType === "start" ? "minDate" : "maxDate";
		const date = this.transformDateForSibling(
			Flatpickr.parseDate(dateStr),
			option,
		);

		if (!date) return this.sibling._flatpickr.set(option, null);

		this.sibling._flatpickr.set(option, date);
	}
	getLimitFromSibling() {
		if (this.calType === "single" || !this.sibling || !this.calInstance) return;

		const option = this.calType === "start" ? "maxDate" : "minDate";
		const date = this.transformDateForSibling(
			Flatpickr.parseDate(this.sibling.value),
			option,
		);

		this.calInstance.set(option, date);
	}
	transformDateForSibling(date, option) {
		if (!date) return date;
		if (this.isDateTime === this.elementIsDateTime(this.sibling)) return date;

		if (option === "maxDate") date.setHours(23, 59, 59);
		else date.setHours(0, 0, 0);

		return date;
	}
	async loadHolidays(year) {
		const promise = DataCycle.httpRequest("/holidays", {
			body: {
				year: year,
			},
		});

		const promiseKey = `${this.cacheNamespace}/${year}`;
		DataCycle.globalPromises[promiseKey] = promise;

		const holidays = (await promise) || [];

		LocalStorageCache.set(this.cacheNamespace, year, holidays);
		DataCycle.globalPromises[promiseKey] = undefined;

		return holidays;
	}
	async createDayElement(_dObj, _dStr, _fp, dayElem) {
		if (dayElem.classList.contains("dc-holidays-initialized")) return;

		await this.markHoliday(dayElem, dayElem.dateObj.getFullYear());
		dayElem.classList.add("dc-holidays-initialized");
	}
	async markHoliday(dayElem, year) {
		const promiseKey = `${this.cacheNamespace}/${year}`;
		let holidays = LocalStorageCache.get(this.cacheNamespace, year);
		if (!holidays && DataCycle.globalPromises[promiseKey])
			holidays = await DataCycle.globalPromises[promiseKey];
		else if (!holidays) holidays = await this.loadHolidays(year);

		const holiday = holidays.find(
			(v) => v.date === Flatpickr.formatDate(dayElem.dateObj, "Y-m-d"),
		);

		if (holiday) {
			dayElem.classList.add("holiday");
			dayElem.title = holiday.name;
		}
	}
	options() {
		const options = Object.assign({}, this.defaultOptions);

		if (this.isDateTime || this.configs?.enableTime) {
			this.isDateTime = true;
			Object.assign(options, this.dateTimeOptions);
		}

		if (this.element.dataset.type === "timepicker")
			Object.assign(options, this.timeOptions);

		return options;
	}
	async importData(event, data) {
		event.stopImmediatePropagation();

		if (this.calInstance.altInput.value.length === 0 || data?.force) {
			this.setDate(null, data.value);
			this.updateConditionalField(data.value);
		} else {
			const target = event.currentTarget;

			DomElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => {
					this.setDate(null, data.value);
					this.updateConditionalField(data.value);
				},
			);
		}
	}
	clear(_event) {
		this.setDate(null);
		this.updateConditionalField(null);
	}
	updateConditionalField(value) {
		$(this.conditionalFormField).trigger("dc:conditionalField:refresh", {
			value:
				value?.length ||
				$(this.conditionalFormField)
					.find(".conditional-field-content :input")
					.serializeArray()
					.filter((v) => v?.value?.trim().length).length,
		});
	}
}

export default DatePicker;
