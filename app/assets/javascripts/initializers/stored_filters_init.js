export default function () {
  if ($('.stored-searches-list').length) {
    $('.stored-searches-list').on('click', '.stored-searches-load-more-button', event => {
      event.preventDefault();
      event.stopPropagation();

      const target = event.currentTarget;

      if (!target.href) return;

      DataCycle.disableElement(target);

      DataCycle.httpRequest({
        url: target.href,
        data: {
          last_day: $('.stored-search-day').last().data('day')
        },
        dataType: 'json',
        contentType: 'application/json'
      })
        .then(data => {
          $(data.html)
            .replaceAll($(target.closest('li.load-more-link')))
            .trigger('dc:html:changed')
            .trigger('dc:html:initialized');
        })
        .catch(_error => {
          DataCycle.enableElement(target);
        });
    });

    $('.fulltext-search-form').on('submit', event => {
      event.preventDefault();
      event.stopPropagation();

      const target = event.currentTarget;
      const inputs = target.querySelectorAll('.fulltext-search-submit, .fulltext-search-field, .fulltext-search-reset');

      if (!target.action) return;

      for (const input of inputs) DataCycle.disableElement(input);
      for (const toRemove of target.closest('ul').querySelectorAll('li:not(.title)')) toRemove.remove();

      DataCycle.httpRequest({
        url: target.action,
        data: {
          q: target.querySelector('.fulltext-search-field').value
        },
        dataType: 'json',
        contentType: 'application/json'
      })
        .then(data => {
          $(data.html)
            .replaceAll($(target.closest('li.load-more-link')))
            .trigger('dc:html:changed')
            .trigger('dc:html:initialized');
        })
        .finally(() => {
          for (const input of inputs) DataCycle.enableElement(input);
        });
    });
  }
}
