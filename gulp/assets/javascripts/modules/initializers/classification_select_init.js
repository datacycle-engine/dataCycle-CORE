// Classification Selctor in Edit Forms
require('select2');
require('select2/i18n/de');
var SimpleSelect2 = require('../components/simple_select2');
var AsyncSelect2 = require('../components/async_select2');
var CheckBoxSelector = require('../components/check_box_selector');
var RadioButtonSelector = require('../components/radio_button_selector');
$.fn.select2.defaults.set('language', $.fn.select2.amd.require('select2/i18n/de'));

module.exports.initialize = function ($) {
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
};
