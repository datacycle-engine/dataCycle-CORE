require('select2');
require('select2/i18n/de');
$.fn.select2.defaults.set('language', $.fn.select2.amd.require("select2/i18n/de"));
var select2_helpers = require('./../helpers/select2_helpers');

module.exports.initialize = function () {
  if ($('#classification-administration').length) {
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
        templateSelection: function (data, container) {
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
              results: data.map(value => {
                if (value.classification_id != undefined) value.id = value.classification_id;
                return value;
              })
            };
          }
        }
      });

      return false;
    });
    $('#classification-administration').on('click', '.discard', function (event) {
      $(this).parent('form').get(0).reset();
      $(this).closest('li.active').removeClass('active');
      return false;
    });

  }

  // Themenbaum

  if ($('#classification-tree-label-list').length) {
    $('#classification-tree-label-list').on('ajax:beforeSend', 'a', function (event, xhr, options) {
      var childrenContainer = $(event.target).closest('li').children('ul.children, ul.contents');

      childrenContainer.siblings('.inner-item').toggleClass('open');

      if (childrenContainer.hasClass('loaded') && options.type != 'POST') {
        childrenContainer.toggle();

        return false;
      }
    });

    let location_array = location.hash.substr(1).split('+').filter(Boolean);
    load_sub_classifications(location_array, 0);
  }
}

function load_sub_classifications(location_array, index) {
  if (location_array != undefined && index < location_array.length) {
    let id = location_array[index];
    let link = $('#' + id + ' > .inner-item > .tree-link');

    if (!link.length) {
      let prev_id = '';
      if (index == 0) {
        prev_id = $('ul.backend-treeview-list > li').first().prop('id');
      } else {
        prev_id = location_array[index - 1];
      }

      let more_link = $('#' + prev_id + ' > .children > .load-more-link > .inner-item > a').last();

      more_link.on('ajax:complete', (event, xhr, options) => {
        more_link.off('ajax:complete');
        if ($('#' + id + ' > .inner-item > .tree-link').length) {
          document.getElementById(id).scrollIntoView({
            behavior: 'smooth'
          });
        } else {
          $('#' + prev_id + ' > .children > li').last().get(0).scrollIntoView({
            behavior: 'smooth'
          });
        }
        load_sub_classifications(location_array, index);
      });

      more_link.click();
    } else {
      link.on('ajax:complete', (event, xhr, options) => {
        link.off('ajax:complete');
        document.getElementById(id).scrollIntoView({
          behavior: 'smooth'
        });

        if (location_array != undefined && index < location_array.length) {
          load_sub_classifications(location_array, index + 1);
        }
      });

      link.click();
    }
  }
};
