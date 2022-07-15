import SimpleSelect2 from '../components/simple_select2';
import AsyncSelect2 from '../components/async_select2';
import CheckBoxSelector from '../components/check_box_selector';
import RadioButtonSelector from '../components/radio_button_selector';

export default function () {
  // FIXME: remove when https://github.com/select2/select2/issues/5993 is resolved
  $(document).on('select2:open', e => {
    const searchField = e.target.parentNode.querySelector('.select2-search__field');
    if (searchField) searchField.focus();
  });

  for (const element of document.querySelectorAll(
    '.form-element.classification.check_box > ul.classification-checkbox-list'
  ))
    new CheckBoxSelector(element).init();

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('classification-checkbox-list'),
    e => new CheckBoxSelector(e).init()
  ]);

  for (const element of document.querySelectorAll(
    '.form-element.classification.radio_button > ul.classification-radiobutton-list'
  ))
    new RadioButtonSelector(element).init();

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('classification-radiobutton-list'),
    e => new RadioButtonSelector(e).init()
  ]);

  for (const element of document.querySelectorAll('.auto-tagging-button')) initAutoTagging(element);
  DataCycle.htmlObserver.addCallbacks.push([e => e.classList.contains('auto-tagging-button'), e => initAutoTagging(e)]);

  for (const element of document.querySelectorAll('.async-select')) new AsyncSelect2(element).init();
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('async-select'),
    e => new AsyncSelect2(e).init()
  ]);

  for (const element of document.querySelectorAll('.single-select, .multi-select')) new SimpleSelect2(element).init();
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('single-select') || e.classList.contains('multi-select'),
    e => new SimpleSelect2(e).init()
  ]);
}

function initAutoTagging(element) {
  $(element).on('click', event => {
    $(event.target).closest('.form-element').find('> .v-select > select').val(null).trigger('change');
  });
}
