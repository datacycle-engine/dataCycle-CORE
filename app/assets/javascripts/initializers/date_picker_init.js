import DataPicker from './../components/date_picker';

export default function () {
  const dateSelectors = [
    'input[type=datetime-local]:not([readonly]):not(:disabled)',
    'input[type=date]:not([readonly]):not(:disabled)',
    'input[data-type=datepicker]:not([readonly]):not(:disabled)'
  ];

  init(document);

  $(document).on('dc:html:changed dc:date:initialize', '*', (event, data) => {
    event.stopPropagation();

    init(event.target, data);
  });

  function init(element, additionalOptions = {}) {
    $(element)
      .find(dateSelectors.join(', '))
      .each((_, elem) => new DataPicker(elem, additionalOptions));
  }
}
