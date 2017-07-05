var Counter = require('./../components/word_counter');

// Word Counter
module.exports.initialize = function () {

  var CounterArray = [];

  $('#edit-form input.form-control[type=text]:not(:disabled)').not('.flatpickr-input').each(function () {
    CounterArray.push(new Counter($(this)));
  });

};