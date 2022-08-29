import AsyncSelect2 from '../components/async_select2';
import QuillHelpers from './../helpers/quill_helpers';

export default function () {
  if ($('#classification-administration').length) {
    $('#classification-administration').on('ajax:beforeSend', 'a:not(.destroy)', function (event) {
      var childrenContainer = $(event.currentTarget).closest('li').children('ul:not(.classifications)');

      if (childrenContainer.children().length > 0 && event.detail[1].type != 'POST') {
        childrenContainer.toggle();

        return false;
      }
    });

    $('#classification-administration').on(
      'ajax:before',
      '.edit_classification_alias, .new_classification_alias',
      event => {
        QuillHelpers.updateEditors(event.currentTarget);
      }
    );

    $('#classification-administration').on('click', 'a.create, a.edit', function (event) {
      $('#classification-administration li.active').removeClass('active');

      $(event.currentTarget).closest('li').addClass('active');

      var select = $(event.currentTarget)
        .closest('li')
        .find('select[name="classification_alias[classification_ids][]"]');

      if (select.length && !select.data('select2')) {
        let newAsyncSelect = new AsyncSelect2(select);
        newAsyncSelect.init();
      }

      var select = $(event.currentTarget).closest('li').find('select[name="classification_alias[mapped_to][]"]');

      if (select.length && !select.data('select2')) {
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

      let locale = $(event.currentTarget).data('locale');
      let caContainer = $(event.currentTarget).closest('form');

      caContainer.find('.list-items a.active').removeClass('active');
      caContainer.find('.list-items [data-locale="' + locale + '"]').addClass('active');
      caContainer.find('.ca-input > .active').removeClass('active');
      caContainer
        .find('.ca-input > .' + locale)
        .addClass('active')
        .trigger('dc:remote:render');
    });
  }

  $(document).on('click', '.toggle-details', event => {
    event.preventDefault();

    $(event.currentTarget).closest('.inner-item').toggleClass('open').trigger('dc:remote:render');
  });
}
