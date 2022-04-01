import ContentLock from '../components/content_lock';

export default function () {
  let locks = [];

  for (const element of document.querySelectorAll('.content-lock')) locks.push(new ContentLock(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('content-lock') && !e.hasOwnProperty('dcContentLock'),
    e => locks.push(new ContentLock(e))
  ]);
}
