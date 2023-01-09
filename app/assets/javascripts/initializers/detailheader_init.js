import ShowMoreLinkToggler from '../components/togglers/show_more_link_toggler';

export default function () {
  $(document).on('click', '.copy-to-clipboard', async event => {
    event.preventDefault();
    var text = $(event.currentTarget).data('value');
    if ($(event.currentTarget).data('json-value')) text = JSON.stringify($(event.currentTarget).data('json-value'));

    var inp = document.createElement('input');
    document.body.appendChild(inp);
    inp.value = text;
    inp.select();
    document.execCommand('copy', false);
    inp.remove();

    $(event.currentTarget).before(
      `<span class="clipboard-notice">${await I18n.translate('actions.copied_to_clipboard')}</span>`
    );
    setTimeout(() => {
      const $notice = $(event.currentTarget).siblings('.clipboard-notice');

      $notice.fadeOut('fast', () => {
        $notice.remove();
      });
    }, 1000);
  });

  for (const element of document.querySelectorAll('.show-more > .show-more-link')) new ShowMoreLinkToggler(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('show-more-link') &&
      e.parentElement.classList.contains('show-more') &&
      !e.classList.contains('dcjs-show-more-link-toggler'),
    e => new ShowMoreLinkToggler(e)
  ]);
}
