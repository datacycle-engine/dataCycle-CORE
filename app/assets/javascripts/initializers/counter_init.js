import Counter from './../components/word_counter';

export default function () {
  DataCycle.initNewElements(
    'input[type=text].form-control:not(:disabled):not(.flatpickr-input):not(.dcjs-counter)',
    e => new Counter(e).start()
  );
}
