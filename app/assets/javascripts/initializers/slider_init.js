import domElementHelpers from '../helpers/dom_element_helpers';

export default function () {
  $('.edit-content-form .form-element.number.duration > .duration-slider > div > :input[type="number"]')
    .on('dc:import:data', async (event, data) => {
      if ($(event.target).val().length === 0) {
        $(event.target).val(data.value).trigger('change');
      } else {
        const target = event.currentTarget;

        domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => {
          $(target).val(data.value).trigger('change');
        });
      }
    })
    .addClass('dc-import-data');
}
