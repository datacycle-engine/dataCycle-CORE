import DatePicker from './../components/date_picker';

export default function () {
  const dateSelectors = [
    'input[type=datetime-local]:not([readonly]):not(:disabled)',
    'input[type=date]:not([readonly]):not(:disabled)',
    'input[data-type=datepicker]:not([readonly]):not(:disabled)',
    'input[data-type=timepicker]:not([readonly]):not(:disabled)'
  ];

  for (const element of document.querySelectorAll(dateSelectors.join(', '))) new DatePicker(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.nodeName == 'INPUT' &&
      !e.disabled &&
      !e.readOnly &&
      !e.classList.contains('flatpickr-input') &&
      (e.type == 'datetime-local' ||
        e.type == 'date' ||
        e.dataset.type == 'datepicker' ||
        e.dataset.type == 'timepicker') &&
      !e.hasOwnProperty('dcDatePicker'),
    e => new DatePicker(e)
  ]);
}
