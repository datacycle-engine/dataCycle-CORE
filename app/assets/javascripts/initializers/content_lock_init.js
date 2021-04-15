// Lock Content when accessing the edit view
import ContentLock from '~/javascripts/components/content_lock';

export default function () {
  let locks = [];
  $('.content-lock').each((_, element) => {
    locks.push(new ContentLock(element, $(element).hasClass('submit-edit-form')));
  });
}
