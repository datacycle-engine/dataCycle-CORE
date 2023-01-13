import ShowMoreLinkToggler from '../components/togglers/show_more_link_toggler';
import CopyToClipboard from '../components/copy_to_clipboard';

export default function () {
  for (const element of document.querySelectorAll('.copy-to-clipboard')) new CopyToClipboard(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('copy-to-clipboard') && !e.classList.contains('dcjs-copy-to-clipboard'),
    e => new CopyToClipboard(e)
  ]);

  for (const element of document.querySelectorAll('.show-more > .show-more-link')) new ShowMoreLinkToggler(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('show-more-link') &&
      e.parentElement.classList.contains('show-more') &&
      !e.classList.contains('dcjs-show-more-link-toggler'),
    e => new ShowMoreLinkToggler(e)
  ]);
}
