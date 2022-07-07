import NewContentDialog from './../components/new_content_dialog';
import DragAndDropField from '../components/drag_and_drop_field';
import loadingIcon from '../templates/loadingIcon';

export default function () {
  for (const element of document.querySelectorAll('form.multi-step')) new NewContentDialog(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.nodeName == 'FORM' && e.classList.contains('multi-step'),
    e => new NewContentDialog(e)
  ]);

  for (const element of document.querySelectorAll('.content-uploader')) new DragAndDropField(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('content-uploader'),
    e => new DragAndDropField(e)
  ]);

  $(document).on('ajax:before', '.new-content-reveal [data-remote]', event => {
    $(event.target).closest('.new-content-reveal').find('.new-content-form').html(loadingIcon('show'));
  });

  $(document).on('ajax:error', '.new-content-reveal [data-remote]', async event => {
    $(event.target)
      .closest('.new-content-reveal')
      .find('.new-content-form')
      .html(await I18n.translate('frontend.load_error'));
  });
}
