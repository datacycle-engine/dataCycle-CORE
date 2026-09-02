import { Turbo } from "@hotwired/turbo-rails";

export default class BulkDeleteButton {
	static selector = ".bulk-delete-button";
	static className = "dcjs-bulk-delete-button";
	constructor(element) {
		this.deleteButton = element;
		this.cableConfig = {
			channel: "DataCycleCore::WatchListBulkDeleteChannel",
			watch_list_id: this.deleteButton.dataset.id,
		};

		this.init();
	}
	async init() {
		const cable = await DataCycle.cable;

		cable.subscriptions.create(this.cableConfig, {
			received: (data) => {
				if (!this.deleteButton.disabled)
					DataCycle.disableElement(this.deleteButton);
				if (data.progress !== undefined)
					this.renderProgress(data.progress, data.items);
				// the delete finished: apply the resulting stream and hand the button back.
				// enableElement restores the button's original content, which is what the
				// progress bar replaced, so there is nothing left to reset.
				if (data.turbo_stream !== undefined) {
					Turbo.renderStreamMessage(data.turbo_stream);
					DataCycle.enableElement(this.deleteButton);
					this.emptyResultCount();
				}
			},
		});
	}
	// The stream only removes rows or replaces #search-results; the total lives outside both, under
	// #search-form. Emptying it is what makes its observer re-fetch the new total (see
	// components/result_count) — without this the count keeps the value it had before the delete.
	emptyResultCount() {
		const resultCount = document.querySelector("#search-form .result-count");

		if (resultCount) resultCount.innerHTML = "";
	}
	// The progress bar only exists while the button is disabled, since it is rendered from the
	// button's data-disable-with content.
	renderProgress(done, total) {
		const progress = Math.round((done * 100) / total);
		const value = this.deleteButton.querySelector(".progress-value");
		const filled = this.deleteButton.querySelector(
			".progress-bar > .progress-filled",
		);

		if (value) value.textContent = `${progress}%`;
		if (filled) filled.style.width = `calc(${progress}% - 1rem)`;
	}
}
