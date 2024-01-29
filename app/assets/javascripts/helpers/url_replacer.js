export default {
	isPersistedUrlParam: (key) => {
		return ["mode", "page", "ctl_id", "ct_id", "stored_filter"].includes(key);
	},
	cleanSearchFormParams: function () {
		const searchForm = document.getElementById("search-form");
		if (!searchForm) return;

		const url = new URL(window.location);
		const params = url.searchParams;
		const storedFilterId =
			params.get("stored_filter") || searchForm.dataset.storedFilter;
		const ctlId = params.get("ctl_id") || searchForm.dataset.ctlId;
		const ctId = params.get("ct_id") || searchForm.dataset.ctId;
		const mode = params.get("mode") || searchForm.dataset.mode || "grid";
		const thingId = params.get("thing_id");
		const page = params.get("page") || 1;

		const state = {
			mode: mode,
			page: page,
			storedFilterId: storedFilterId,
		};

		if (!storedFilterId) params.delete("stored_filter");
		else if (storedFilterId !== params.get("stored_filter"))
			params.set("stored_filter", storedFilterId);

		if (mode !== "grid") params.set("mode", mode);
		else params.delete("mode");

		if (page <= 1) params.delete("page");

		if (ctlId) {
			params.set("ctl_id", ctlId);
			state.ctlId = ctlId;
		}
		if (ctId) {
			params.set("ct_id", ctId);
			state.ctId = ctId;
		}
		if (thingId) {
			window.location.hash = thingId;
			state.thingId = thingId;
		}

		for (const key of params.keys())
			if (!this.isPersistedUrlParam(key)) params.delete(key);

		if (window.location.href !== url.toString())
			history.replaceState(state, "", url);
	},
};
