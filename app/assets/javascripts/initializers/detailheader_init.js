import ShowMoreLinkToggler from '../components/togglers/show_more_link_toggler';
import CopyToClipboard from '../components/copy_to_clipboard';

export default function () {
  DataCycle.initNewElements('.copy-to-clipboard:not(.dcjs-copy-to-clipboard)', e => new CopyToClipboard(e));

  DataCycle.initNewElements(
    '.show-more > .show-more-link:not(.dcjs-show-more-link-toggler)',
    e => new ShowMoreLinkToggler(e)
  );
}
