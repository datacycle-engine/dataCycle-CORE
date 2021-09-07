import ConfirmationModal from './../components/confirmation_modal';

export default function () {
  var SliderArray = [];

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  $('.edit-content-form .form-element.number.duration > .duration-slider > div > :input[type="number"]').on(
    'dc:import:data',
    async (event, data) => {
      if ($(event.target).val().length === 0) {
        $(event.target).val(data.value).trigger('change');
      } else {
        new ConfirmationModal({
          text: await I18n.translate('frontend.override_warning', { data: data.label }),
          confirmationText: await I18n.translate('common.yes'),
          cancelText: await I18n.translate('common.no'),
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
