export default {
  persistedUrlParams: function () {
    return ['mode', 'page', 'ctl_id', 'ct_id'];
  },
  paramsToStoredFilterId: function () {
    const searchForm = document.getElementById('search-form');
    if (!searchForm) return;

    const currentStoredFilterId = searchForm.dataset.storedFilter;
    if (!currentStoredFilterId) return;

    const mode = searchForm.dataset.mode;
    const ctlId = searchForm.dataset.ctlId;
    const ctId = searchForm.dataset.ctId;

    const url = new URL(window.location);
    if (url.searchParams.get('stored_filter') == currentStoredFilterId) return;

    const newUrlParams = new URLSearchParams(`stored_filter=${currentStoredFilterId}`);
    for (const param of this.persistedUrlParams())
      if (url.searchParams.has(param)) newUrlParams.set(param, url.searchParams.get(param));

    if (mode) newUrlParams.set('mode', mode);
    if (ctlId) newUrlParams.set('ctl_id', ctlId);
    if (ctId) newUrlParams.set('ct_id', ctId);

    history.replaceState({}, '', `?${newUrlParams.toString()}${url.hash}`);
  }
};
