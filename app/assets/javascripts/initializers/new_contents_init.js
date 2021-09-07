import NewContentDialog from './../components/new_content_dialog';
import DragAndDropField from '../components/drag_and_drop_field';
import loadingIcon from '../templates/loadingIcon';

export default function () {
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  init();

  $(document).on('ajax:before', '.new-content-reveal [data-remote]', event => {
    $(event.target).closest('.new-content-reveal').find('.new-content-form').html(loadingIcon('show'));
  });

  $(document).on('ajax:error', '.new-content-reveal [data-remote]', async event => {
    $(event.target)
      .closest('.new-content-reveal')
      .find('.new-content-form')
      .html(await I18n.translate('frontend.load_error'));
  });

  function init(container = document) {
    $(container)
      .find('form.multi-step')
      .each((_index, element) => {
        new NewContentDialog(element);
      });

    $(container)
      .find('.content-uploader')
      .each((_, e) => {
        new DragAndDropField(e);
      });
  }
}
