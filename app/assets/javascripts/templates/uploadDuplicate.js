export default async function (id, duplicates) {
  return `
    <a class="possible-duplicates" data-toggle="${id}-duplicates-list" title="Duplikate vorhanden" aria-controls="${id}-duplicates-list" aria-haspopup="true">
      <i class="fa fa-exclamation" aria-hidden="true"></i> Duplikate vorhanden
    </a>
    <div class="dropdown-pane no-bullet bottom" id="${id}-duplicates-list" data-dropdown data-hover="true" data-hover-pane="true" aria-hidden="true">
      <h5>mögliche Duplikate</h5>
      <ul class="list-items duplicates-list no-bullet">
      ${duplicates
        .map(
          item =>
            `<li><a target="_blank" class="duplicate-link" href="${DataCycle.joinPath(
              '/',
              DataCycle.config.enginePath,
              'things',
              item.id
            )}"><img class="lazyload" data-src="${item.thumbnail_url}"></li>`
        )
        .join('')}
      </ul></div>
    `;
}
