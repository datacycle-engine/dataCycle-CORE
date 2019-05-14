var ConfirmationModal = require('./../components/confirmation_modal');
var SplitView = require('./../components/split_view');

// Split View Inhalte kopieren
module.exports.initialize = function() {
  init('.flex-box .detail-content .properties');

  function init(container) {
    new SplitView(container);
  }

  // add eventhandlers for editor fields
  $('.edit-content-form .form-element.string:not(.text_editor) > input[type="text"]').on('dc:import:data', function(
    event,
    data
  ) {
    if ($(event.target).val().length === 0) {
      $(event.target)
        .val(data.value)
        .trigger('input');
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function() {
          $(event.target)
            .val(data.value)
            .trigger('input');
        }
      });
    }
  });

  $('.edit-content-form .form-element.number > input[type="number"]').on('dc:import:data', function(event, data) {
    if ($(event.target).val().length === 0) {
      $(event.target)
        .val(data.value)
        .trigger('input');
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function() {
          $(event.target)
            .val(data.value)
            .trigger('input');
        }
      });
    }
  });

  $('.edit-content-form .form-element.boolean :checkbox').on('dc:import:data', function(event, data) {
    new ConfirmationModal({
      text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
      confirmationText: 'Ja',
      cancelText: 'Nein',
      confirmationClass: 'success',
      cancelable: true,
      confirmationCallback: function() {
        $(event.target).prop('checked', data.value);
      }
    });
  });

  // SPLIT CONTENT
  if ($('.split-content').length) {
    $('.split-content').on('mouseover', function() {
      $('.split-content').addClass('nothover');
      $(this).removeClass('nothover');
    });
    $('.has-changes').on('click', function() {
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
              $('.split-content')
                .last()
                .offset().top +
              $('.split-content')
                .last()
                .scrollTop() -
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
              $('.split-content')
                .first()
                .offset().top +
              $('.split-content')
                .first()
                .scrollTop() -
              150
          },
          500
        );
    });
  }
};
