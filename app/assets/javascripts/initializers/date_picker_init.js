import DataPicker from './../components/date_picker';

export default function () {
  const dateSelectors = [
    'input[type=datetime-local]:not([readonly]):not(:disabled)',
    'input[type=date]:not([readonly]):not(:disabled)',
    'input[data-type=datepicker]:not([readonly]):not(:disabled)',
    'input[data-type=timepicker]:not([readonly]):not(:disabled)'
  ];

  init(document);

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.target);
  });

  function init(element) {
    $(element)
      .find(dateSelectors.join(', '))
      .each((_, elem) => new DataPicker(elem));
  }
}
