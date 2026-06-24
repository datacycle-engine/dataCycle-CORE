import { Turbo } from "@hotwired/turbo-rails";

export default function () {
	if ($(".bulk-delete-button").length) {
		const deleteButton = $(".bulk-delete-button");
		window.actionCable.then((cable) => {
			cable.subscriptions.create(
				{
					channel: "DataCycleCore::WatchListBulkDeleteChannel",
					watch_list_id: deleteButton.data("id"),
				},
				{
					received: (data) => {
						if (!deleteButton.prop("disabled"))
							DataCycle.disableElement(deleteButton);
						if (data.progress !== undefined) {
							const progress = Math.round((data.progress * 100) / data.items);
							deleteButton.find(".progress-value").text(`${progress}%`);
							deleteButton
								.find(".progress-bar > .progress-filled")
								.css("width", `calc(${progress}% - 1rem)`);
						}
						if (data.turbo_stream !== undefined) {
							Turbo.renderStreamMessage(data.turbo_stream);
							DataCycle.enableElement(deleteButton);
							// emptying the count triggers its observer to re-fetch the updated total
							const resultCount = document.querySelector(
								"#search-form .result-count",
							);
							if (resultCount) resultCount.innerHTML = "";
						}
					},
				},
			);
		});
	}
}
