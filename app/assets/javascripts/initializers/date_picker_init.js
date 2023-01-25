import DatePicker from './../components/date_picker';

export default function () {
  const dateSelectors = [
    'input[type=datetime-local]',
    'input[type=date]',
    'input[data-type=datepicker]',
    'input[data-type=timepicker]'
  ];

  DataCycle.initNewElements(
    dateSelectors
      .map(c => `${c}:not(:disabled):not(:read-only):not(.flatpickr-input):not(.dcjs-date-picker)`)
      .join(', '),
    e => new DatePicker(e)
  );
}
