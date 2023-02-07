import ContentLock from '../components/content_lock';

export default function () {
  DataCycle.initNewElements('.content-lock:not(.dcjs-content-lock)', e => new ContentLock(e));
}
