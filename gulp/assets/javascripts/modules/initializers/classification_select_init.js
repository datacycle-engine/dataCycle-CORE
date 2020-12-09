// Classification Selctor in Edit Forms
require('select2');
require('select2/i18n/de');
var SimpleSelect2 = require('../components/simple_select2');
var AsyncSelect2 = require('../components/async_select2');
$.fn.select2.defaults.set('language', $.fn.select2.amd.require('select2/i18n/de'));

module.exports.initialize = function ($) {
  let asyncSelects = [];
  let simpleSelects = [];

  let init = function (element) {
    $(element)
      .find('.form-element.classification.check_box > ul.classification-checkbox-list')
      .on('dc:import:data', function (event, data) {
        $(event.target)
          .find('> li > :checkbox')
          .each((_, item) => {
            $(item).prop('checked', data.value !== undefined && data.value.includes($(item).val()));
          });
      });

    $(element)
      .find('.form-element.classification.radio_button > ul.classification-radiobutton-list')
      .on('dc:import:data', function (event, data) {
        $(event.target)
          .find('> li > :radio')
          .each((_, item) => {
            if (data.value !== undefined && data.value.includes($(item).val())) $(item).prop('checked', true);
          });
      });

    $('.auto-tagging-button').on('click', event => {
      $(event.target).closest('.form-element').find('> .v-select > select').val(null).trigger('change');
    });

    $(element)
      .find('.async-select')
      .each((_index, item) => {
        let newAsyncSelect = new AsyncSelect2(item);
        newAsyncSelect.init();
        asyncSelects.push(newAsyncSelect);
      });

    $(element)
      .find('.single-select, .multi-select')
      .each((_index, item) => {
        let newSimpleSelect = new SimpleSelect2(item);
        newSimpleSelect.init();
        simpleSelects.push(newSimpleSelect);
      });
  };

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  init(document);
};
