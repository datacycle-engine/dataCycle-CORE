import Counter from './../components/word_counter';

export default function () {
  var CounterArray = {};

  init_counters($('#edit-form'));

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init_counters(event.target);
  });

  function init_counters(container) {
    $(container)
      .find('input.form-control[type=text]:not(:disabled):not(.flatpickr-input)')
      .each((_index, element) => {
        CounterArray[$(element).prop('id')] = new Counter(element).start();
      });
  }
}
