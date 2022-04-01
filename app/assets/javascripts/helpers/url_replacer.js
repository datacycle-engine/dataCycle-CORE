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
    for (let i = 0; i < this.persistedUrlParams.length; ++i) {
      if (url.searchParams.has(this.persistedUrlParams[i]))
        newUrlParams.append(this.persistedUrlParams[i], url.searchParams.get(this.persistedUrlParams[i]));
    }

    if (mode) newUrlParams.append('mode', mode);
    if (ctlId) newUrlParams.append('ctl_id', ctlId);
    if (ctId) newUrlParams.append('ct_id', ctId);

    history.replaceState({}, '', `?${newUrlParams.toString()}`);
  }
};
