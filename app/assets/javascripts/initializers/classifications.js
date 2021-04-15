import AsyncSelect2 from '~/javascripts/components/async_select2';
import quill_helpers from '~/javascripts/helpers/quill_helpers';

export default function () {
  let load_sub_classifications = function (location_array, index) {
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
            $('#' + prev_id + ' > .children > li')
              .last()
              .get(0)
              .scrollIntoView({
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

  if ($('#classification-administration').length) {
    $('#classification-administration').on('ajax:beforeSend', 'a:not(.destroy)', function (event, xhr, options) {
      var childrenContainer = $(event.target).closest('li').children('ul:not(.classifications)');

      if (childrenContainer.children().length > 0 && options.type != 'POST') {
        childrenContainer.toggle();

        return false;
      }
    });

    $('#classification-administration').on(
      'ajax:before',
      '.edit_classification_alias, .new_classification_alias',
      (event, xhr, options) => {
        quill_helpers.updateEditors(event.target);
      }
    );

    $('#classification-administration').on('click', 'a.create, a.edit', function (event) {
      $('#classification-administration li.active').removeClass('active');

      $(event.target).closest('li').addClass('active');

      var select = $(event.target).closest('li').find('select[name="classification_alias[classification_ids][]"]');

      if (!select.data('select2')) {
        let newAsyncSelect = new AsyncSelect2(select);
        newAsyncSelect.init();
      }

      return false;
    });
    $('#classification-administration').on('click', '.discard', function (event) {
      $(this).parents('form').get(0).reset();
      $(this).closest('li.active').removeClass('active');

      return false;
    });
    $('#classification-administration').on('click', '.ca-translation-link', event => {
      event.preventDefault();

      let locale = $(event.target).data('locale');
      let caContainer = $(event.target).closest('form');

      caContainer.find('.list-items a.active').removeClass('active');
      caContainer.find('.list-items [data-locale="' + locale + '"]').addClass('active');
      caContainer.find('.ca-input > .active').removeClass('active');
      caContainer
        .find('.ca-input > .' + locale)
        .addClass('active')
        .trigger('dc:remote:render');
    });
  }

  // Themenbaum

  if ($('#classification-tree-label-list, #search-results > .tree').length) {
    $('#classification-tree-label-list, #search-results').on('ajax:beforeSend', 'a', function (event, xhr, options) {
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

  $(document).on('click', '.toggle-details', event => {
    event.preventDefault();

    $(event.currentTarget).closest('.inner-item').toggleClass('open').trigger('dc:remote:render');
  });
}
