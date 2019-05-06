var ConfirmationModal = require('./../components/confirmation_modal');
var SplitView = require('./../components/split_view');

// Split View Inhalte kopieren
module.exports.initialize = function() {
  init('.flex-box .detail-content .properties');

  function init(container) {
    new SplitView(container);
  }

  $('.edit-content-form .form-element.string:not(.text_editor)').on('dc:import:data', function(event, data) {
    if (
      $(this)
        .find('input[type=text]')
        .val().length === 0
    ) {
      $(this)
        .find('input[type=text]')
        .val(data.value)
        .trigger('input');
    } else {
      var confirmationModal = new ConfirmationModal(
        data.label + ' wird überschrieben. <br>Fortfahren?',
        'success',
        true,
        function() {
          $(this)
            .find('input[type=text]')
            .val(data.value)
            .trigger('input');
        }.bind(this)
      );
    }
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
