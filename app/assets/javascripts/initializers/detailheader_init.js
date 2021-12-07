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

  $(document).on('click', '.show-more .show-more-link', event => {
    event.preventDefault();

    $(event.currentTarget)
      .parent('.show-more')
      .toggleClass('active')
      .get(0)
      .scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  });

  $(document).on('click', '.toggler', event => {
    event.preventDefault();

    $(event.currentTarget).toggleClass('active');

    $('#' + $(event.currentTarget).data('toggle'))
      .toggleClass('active')
      .trigger('dc:toggler:show')
      .get(0)
      .scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  });
}
