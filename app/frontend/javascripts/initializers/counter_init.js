import Counter from '~/javascripts/components/word_counter';

// Word Counter
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
      .each((index, element) => {
        CounterArray[$(element).prop('id')] = new Counter(element).start();
      });
  }
}
