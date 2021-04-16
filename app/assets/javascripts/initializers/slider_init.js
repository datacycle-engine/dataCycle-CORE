import ConfirmationModal from './../components/confirmation_modal';

export default function () {
  var SliderArray = [];

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  $('.edit-content-form .form-element.number.duration > .duration-slider > div > :input[type="number"]').on(
    'dc:import:data',
    function (event, data) {
      if ($(event.target).val().length === 0) {
        $(event.target).val(data.value).trigger('change');
      } else {
        var confirmationModal = new ConfirmationModal({
          text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
          confirmationText: 'Ja',
          cancelText: 'Nein',
          confirmationClass: 'success',
          cancelable: true,
          confirmationCallback: function () {
            $(event.target).val(data.value).trigger('change');
          }
        });
      }
    }
  );

  function init(element = document) {
    $(element)
      .find('.slider')
      .each(function () {
        SliderArray.push(new Foundation.Slider($(this)));
      });
  }
}
