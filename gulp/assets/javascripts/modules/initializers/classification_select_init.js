// Classification Selctor in Edit Forms
require('select2');
require('select2/i18n/de');
var select2_helpers = require('./../helpers/select2_helpers');

module.exports.initialize = function () {

  $('.async-select').each(function () {

    var query = {};
    var tree_label = $(this).data('tree-label');

    $(this).select2({
      minimumInputLength: 0,
      language: 'de',
      escapeMarkup: function (m) {
        return m;
      },
      templateResult: function (data) {
        if (data.loading) {
          return data.path;
        }
        var term = query.term || '';

        var result = data.path ? select2_helpers.markMatch(data.path, term) : null;

        return result;
      },
      templateSelection: function (data) {
        return data.name || data.text;
      },
      ajax: {
        url: '/classifications/search',
        delay: 250,
        data: function (params) {
          query = params;
          return {
            q: params.term,
            tree_label: tree_label
          };
        },
        processResults: function (data) {
          return {
            results: data
          };
        }
      }
    });
  });

  $('.single-select').each(function () {

    var query = {};

    $(this).select2({
      language: 'de',
      allowClear: true,
      width: '100%'
    });
  });

};
