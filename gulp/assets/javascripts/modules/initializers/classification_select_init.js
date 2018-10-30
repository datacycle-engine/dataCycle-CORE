// Classification Selctor in Edit Forms
require('select2');
require('select2/i18n/de');
$.fn.select2.defaults.set('language', $.fn.select2.amd.require("select2/i18n/de"));
var select2_helpers = require('./../helpers/select2_helpers');

module.exports.initialize = function () {

  let init = function (element) {
    $(element).find('.async-select').each(function () {
      var query = {};
      var tree_label = $(this).data('tree-label');
      var alias_ids = $(this).data('alias-ids') || false;
      var max = $(this).data('max');
      var that = this;

      $(this).select2({
        allowClear: true,
        minimumInputLength: 2,
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
          select2_helpers.removeTreeLabel(result, tree_label);
          select2_helpers.decorateResult(result);

          if (data.description) {
            result.attr('title', data.title + '\n\n' + data.description);
            data.title = data.title + '\n\n' + data.description;
          }

          return result;
        },
        templateSelection: function (data) {
          data.selected = true;
          data.text = data.name || data.text;
          $(data.element).text(data.text);
          return data.text;
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
              results: data.map(value => {
                if (alias_ids && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
                else if (value.classification_id != undefined) value.id = value.classification_id;
                return value;
              })
            };
          }
        }
      });
    });

    $(element).find('.single-select, .multi-select').each(function () {
      var query = {};
      var tree_label = $(this).data('tree-label');
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
          var text_value = data.name || data.text;
          var result = text_value ? select2_helpers.markMatch(text_value, term) : null;
          select2_helpers.removeTreeLabel(result, tree_label);
          select2_helpers.decorateResult(result);

          return result;
        },
        language: {
          searching: function (params) {
            query = params;

            return '';
          }
        },
        templateSelection: function (data) {
          return select2_helpers.removeTreeLabelFromSelection(data.text, tree_label);
        }
      });
    });
  };

  function removeHandlers(element) {
    $(element).find('.single-select, .multi-select, .async-select').each((_, element) => {
      $(element).select2('destroy');
    });
  };

  $(document).on('form-rendered remote-partial-rendered', event => {
    init(event.target);
  });

  $(document).on('open.zf.reveal', '.new-content-reveal[data-reset-on-close]', event => {
    init(event.target);
  });

  $(document).on('closed.zf.reveal', '.new-content-reveal[data-reset-on-close]', event => {
    removeHandlers(event.target);
  });

  $(document).on('clone-added', '.content-object-item, .advanced-filter', function () {
    init(this);
  });

  init(document);

};
