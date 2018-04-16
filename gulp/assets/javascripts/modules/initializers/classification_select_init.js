// Classification Selctor in Edit Forms
require('select2');
require('select2/i18n/de');
$.fn.select2.defaults.set('language', $.fn.select2.amd.require("select2/i18n/de"));
var select2_helpers = require('./../helpers/select2_helpers');

module.exports.initialize = function () {

  $(document).on('clone-added', '.content-object-item', function () {
    init(this);
  });

  init(document);

  function init(element) {
    $(element).find('.async-select').each(function () {
      var query = {};
      var tree_label = $(this).data('tree-label');
      var max = $(this).data('max');
      var that = this;

      $(this).select2({
        allowClear: true,
        minimumInputLength: 0,
        dropdownParent: $(that).parent(),
        escapeMarkup: function (m) {
          return m;
        },
        templateResult: function (data) {
          if (data.loading) {
            return data.title;
          }

          var term = query.term || '';
          var result = data.title ? select2_helpers.markMatch(data.title, term) : null;
          select2_helpers.decorateResult(result);

          return result;
        },
        templateSelection: function (data) {
          return data.name || data.text;
        },
        ajax: {
          url: '/classifications/search',
          delay: 250,
          data: function (params) {
            $(that).data('select2').$container.addClass('select2-loading');
            query = params;
            return {
              q: params.term,
              tree_label: tree_label,
              max: max
            };
          },
          processResults: function (data) {
            $(that).data('select2').$container.removeClass('select2-loading');
            return {
              results: data
            };
          }
        }
      });
    });

    $(element).find('.single-select, .multi-select').each(function () {
      var query = {};
      var that = this;

      $(this).select2({
        allowClear: true,
        width: '100%',
        dropdownParent: $(that).parent(),
        templateResult: function (data) {
          if (data.loading) {
            return data.text;
          }

          var term = query.term || '';
          var result = data.text ? select2_helpers.markMatch(data.text, term) : null;
          select2_helpers.decorateResult(result);

          return result;
        },
        language: {
          searching: function (params) {
            query = params;

            return '';
          }
        }
      });
    });
  };
};
