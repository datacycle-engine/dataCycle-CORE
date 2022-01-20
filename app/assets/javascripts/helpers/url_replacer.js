export default {
  persistedUrlParams: function () {
    return ['mode', 'page'];
  },
  paramsToStoredFilterId: function () {
    const searchForm = document.getElementById('search-form');
    if (!searchForm) return;

    const currentStoredFilterId = searchForm.dataset.storedFilterId;
    if (!currentStoredFilterId) return;

    const url = new URL(window.location);
    if (url.searchParams.get('stored_filter') == currentStoredFilterId) return;

    const newUrlParams = new URLSearchParams(`stored_filter=${currentStoredFilterId}`);
    for (let i = 0; i < this.persistedUrlParams.length; ++i) {
      if (url.searchParams.has(this.persistedUrlParams[i]))
        newUrlParams.append(this.persistedUrlParams[i], url.searchParams.get(this.persistedUrlParams[i]));
    }

    history.replaceState({}, '', `?${newUrlParams.toString()}`);
  }
};
