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

  let editors = [];
  let init = function (element) {
    $(element)
      .find('.form-element.classification.check_box > ul.classification-checkbox-list')
      .each((_, item) => {
        let newCheckBoxSelector = new CheckBoxSelector(item);
        newCheckBoxSelector.init();
        editors.push(newCheckBoxSelector);
      });
    $(element)
      .find('.form-element.classification.radio_button > ul.classification-radiobutton-list')
      .each((_, item) => {
        let newRadioButtonSelector = new RadioButtonSelector(item);
        newRadioButtonSelector.init();
        editors.push(newRadioButtonSelector);
      });
    $('.auto-tagging-button').on('click', event => {
      $(event.target).closest('.form-element').find('> .v-select > select').val(null).trigger('change');
    });
    $(element)
      .find('.async-select')
      .each((_index, item) => {
        let newAsyncSelect = new AsyncSelect2(item);
        newAsyncSelect.init();
        editors.push(newAsyncSelect);
      });
    $(element)
      .find('.single-select, .multi-select')
      .each((_index, item) => {
        let newSimpleSelect = new SimpleSelect2(item);
        newSimpleSelect.init();
        editors.push(newSimpleSelect);
      });
  };
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });
  init(document);
}
