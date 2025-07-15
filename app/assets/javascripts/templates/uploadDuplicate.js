export default async function (id, duplicates) {
	return `
    <span class="possible-duplicates" data-toggle="${id}-duplicates-list" aria-controls="${id}-duplicates-list" aria-haspopup="true">
      <i class="fa fa-exclamation" aria-hidden="true"></i> ${await I18n.translate("frontend.upload.found_duplicate")}
    </span>
    <div class="dropdown-pane no-bullet bottom" id="${id}-duplicates-list" data-dropdown aria-hidden="true">
      <h5>mögliche Duplikate</h5>
      <ul class="list-items duplicates-list no-bullet">
      ${duplicates
				.map(
					(item) =>
						`<li><a target="_blank" class="duplicate-link" href="${DataCycle.joinPath(
							"/",
							DataCycle.config.enginePath,
							"things",
							item.id,
						)}"><img class="lazyload" data-src="${item.thumbnail_url}"></li>`,
				)
				.join("")}
      </ul></div>
    `;
}
