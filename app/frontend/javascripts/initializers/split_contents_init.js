import ConfirmationModal from '~/javascripts/components/confirmation_modal';
import SplitView from '~/javascripts/components/split_view';

// Split View Inhalte kopieren
export default function () {
  init('.flex-box .detail-content .properties');

  function init(container) {
    new SplitView(container);
  }

  // add eventhandlers for editor fields
  $(document).on(
    'dc:import:data',
    '.form-element.string:not(.text_editor) > input[type="text"]',
    function (event, data) {
      if ($(event.target).val().length === 0 || (data && data.force)) {
        $(event.target).val(data.value).trigger('input');
      } else {
        new ConfirmationModal({
          text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
          confirmationText: 'Ja',
          cancelText: 'Nein',
          confirmationClass: 'success',
          cancelable: true,
          confirmationCallback: function () {
            $(event.target).val(data.value).trigger('input');
          }
        });
      }
    }
  );

  $(document).on('dc:import:data', '.form-element.number > input[type="number"]', function (event, data) {
    if ($(event.target).val().length === 0 || (data && data.force)) {
      $(event.target).val(data.value).trigger('input');
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          $(event.target).val(data.value).trigger('input');
        }
      });
    }
  });

  $(document).on('dc:import:data', '.form-element.boolean :checkbox', function (event, data) {
    if (data && data.force) {
      $(event.target).prop('checked', data.value);
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          $(event.target).prop('checked', data.value);
        }
      });
    }
  });

  // SPLIT CONTENT
  if ($('.split-content').length) {
    $('.split-content').on('mouseover', function () {
      $('.split-content').addClass('nothover');
      $(this).removeClass('nothover');
    });
    $('.has-changes').on('click', function () {
      $('.split-content .properties .selected').removeClass('selected');
      current = $(this).data('label');
      newelem = $('.split-content')
        .last()
        .find("[data-label='" + current + "']");
      newelem.addClass('selected');
      $('.split-content')
        .last()
        .animate(
          {
            scrollTop:
              newelem.offset().top -
              $('.split-content').last().offset().top +
              $('.split-content').last().scrollTop() -
              150
          },
          500
        );
      $('.split-content')
        .first()
        .animate(
          {
            scrollTop:
              $(this).offset().top -
              $('.split-content').first().offset().top +
              $('.split-content').first().scrollTop() -
              150
          },
          500
        );
    });
  }
}
