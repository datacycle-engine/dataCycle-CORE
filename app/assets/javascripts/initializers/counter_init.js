import Counter from './../components/word_counter';

export default function () {
  for (const element of document.querySelectorAll(
    '#edit-form input.form-control[type=text]:not(:disabled):not(.flatpickr-input)'
  ))
    new Counter(element).start();

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.nodeName == 'INPUT' &&
      e.type == 'text' &&
      !e.disabled &&
      e.classList.contains('form-control') &&
      !e.classList.contains('flatpickr-input'),
    e => new Counter(e).start()
  ]);
}
