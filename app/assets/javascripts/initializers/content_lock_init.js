import ContentLock from '../components/content_lock';

export default function () {
  let locks = [];
  $('.content-lock').each((_, element) => {
    locks.push(new ContentLock(element));
  });

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('content-lock'),
    e => locks.push(new ContentLock(e))
  ]);
}
