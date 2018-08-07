var Counter = require('./../components/word_counter');

// Word Counter
module.exports.initialize = function () {

  var CounterArray = [];

  $('#edit-form input.form-control[type=text]:not(:disabled)').not('.flatpickr-input').each(function () {
    CounterArray.push(new Counter(this));
  });

  $(document).on('open.zf.reveal', '[data-reset-on-close="true"]', function (event) {
    $(this).find('input.form-control[type=text]:not(:disabled)').not('.flatpickr-input').each(function () {
      let index = CounterArray.findIndex(element => $(this).is($(element.$parent)));
      CounterArray.splice(index, 1);
      CounterArray.push(new Counter(this));
    });
  });

  $(document).on('clone-added', '.content-object-item', function () {

    $(this).find('input.form-control[type=text]:not(:disabled)').not('.flatpickr-input').each(function () {
      CounterArray.push(new Counter(this));
    });
  });

};
