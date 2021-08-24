import I18n from '../components/i18n';

export default function () {
  $('.copy-to-admin-clipboard').on('click', async event => {
    event.preventDefault();
    var text = $(event.currentTarget).closest('section.tabs-panel').find('pre code');

    if ($(text).data('json')) text = JSON.stringify($(text).data('json'));
    else text = $(text).html();

    var inp = document.createElement('input');
    document.body.appendChild(inp);
    inp.value = text;
    inp.select();
    document.execCommand('copy', false);
    inp.remove();

    $(event.currentTarget).before(
      `<span class="admin-clipboard-notice">${await I18n.translate('actions.copied_to_clipboard')}</span>`
    );

    setTimeout(() => {
      const $notice = $(event.currentTarget).siblings('.admin-clipboard-notice');
      $notice.fadeOut('fast', () => {
        $notice.remove();
      });
    }, 1000);
  });
}
