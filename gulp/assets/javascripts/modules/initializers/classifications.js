require('select2');
require('select2/i18n/de');
var select2_helpers = require('./../helpers/select2_helpers');

module.exports.initialize = function () {
  $('#classification-administration').on('ajax:beforeSend', 'a:not(.destroy)', function (event, xhr, options) {
    var childrenContainer = $(event.target).closest('li').children('ul:not(.classifications)');

    if (childrenContainer.children().length > 0 && options.type != 'POST') {
      childrenContainer.toggle();

      return false;
    }
  });

  $('#classification-administration').on('click', 'a.create, a.edit', function (event) {
    $('#classification-administration li.active').removeClass('active');

    $(event.target).closest('li').addClass('active');

    var classificationAliasId = $(event.target).closest('li').find('input[name="classification_alias[id]"]').val();

    var select = $(event.target).closest('li').find('select[name="classification_alias[classification_ids][]"]');

    var query = {};

    select.select2({
      tags: true,
      minimumInputLength: 1,
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
          select.data('select2').$container.addClass('select2-loading');
          query = params;
          return {
            q: params.term
          };
        },
        processResults: function (data) {
          select.data('select2').$container.removeClass('select2-loading');
          return {
            results: data
          };
        }
      }
    });

    return false;
  });
  $('#classification-administration').on('click', 'a.discard', function (event) {
    $(this).parent('li').removeClass('active');
    return false;
  });

}
