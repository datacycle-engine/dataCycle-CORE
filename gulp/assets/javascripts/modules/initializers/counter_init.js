var Counter = require('./../components/word_counter');

// Word Counter
module.exports.initialize = function() {
  var CounterArray = {};

  init_counters($('#edit-form'));

  $(document).on('changed.dc.html', '*', event => {
    init_counters(event.target);
  });

  function init_counters(container) {
    $(container)
      .find('input.form-control[type=text]:not(:disabled):not(.flatpickr-input)')
      .each((index, element) => {
        CounterArray[$(element).prop('id')] = new Counter(element);
      });
  }
};
