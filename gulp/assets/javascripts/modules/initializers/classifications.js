require('select2');
require('select2/i18n/de');

module.exports.initialize = function () {
  $('#classification-administration').on('ajax:beforeSend', 'a:not(.destroy)', function(event, xhr, options) {
    var childrenContainer = $(event.target).closest('li').children('ul:not(.classifications)');

    if (childrenContainer.children().length > 0 && options.type != 'POST') {
      childrenContainer.toggle();

      return false;
    }
  });

  $('#classification-administration').on('click', 'a.create, a.edit', function(event) {
    $('#classification-administration li.active').removeClass('active');

    $(event.target).closest('li').addClass('active');

    var classificationAliasId = $(event.target).closest('li').find('input[name="classification_alias[id]"]').val();

    var $select = $(event.target).closest('li').find('select[name="classification_alias[classification_ids][]"]');

    $select.select2({
      tags: true,
      minimumInputLength: 1,
      language: 'de',
      escapeMarkup: function(m) { return m; },
      templateResult: function(data) {
          return data.path;
      },
      templateSelection: function(data) {
          return data.name || data.text;
      },
      ajax: {
        url: '/classifications/search',
        data: function (params) {
          return {q: params.term};
        },
        processResults: function(data) {
          return {results: data};
        }
      }
    });

    return false;
  });
}
