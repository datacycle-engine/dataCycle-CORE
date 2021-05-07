import ContentLock from '../components/content_lock';

export default function () {
  let locks = [];
  $('.content-lock').each((_, element) => {
    locks.push(new ContentLock(element, $(element).hasClass('submit-edit-form')));
  });
}
