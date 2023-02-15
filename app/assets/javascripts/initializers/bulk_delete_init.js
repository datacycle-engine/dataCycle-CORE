export default function () {
	if ($(".bulk-delete-button").length) {
		let deleteButton = $(".bulk-delete-button");
		window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::WatchListBulkDeleteChannel",
				watch_list_id: deleteButton.data("id"),
			},
			{
				received: (data) => {
					if (!deleteButton.prop("disabled"))
						DataCycle.disableElement(deleteButton);
					if (data.progress !== undefined) {
						let progress = Math.round((data.progress * 100) / data.items);
						deleteButton.find(".progress-value").text(`${progress}%`);
						deleteButton
							.find(".progress-bar > .progress-filled")
							.css("width", `calc(${progress}% - 1rem)`);
					}
					if (data.redirect_path !== undefined) {
						deleteButton.removeAttr("data-disable-with");
						window.location.href = data.redirect_path;
					}
				},
			},
		);
	}
}
