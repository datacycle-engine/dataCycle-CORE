import throttle from "lodash/throttle";

class AdminDashboardJobsChannel {
	static selector = ".card.background-jobs .card-section";
	static className = "dcjs-admin-dashboard-jobs-channel";
	constructor(element) {
		this.element = element;
		this.reload = throttle(this.triggerReload.bind(this), 1000);

		console.log("AdminDashboardJobsChannel initialized", this.element);

		this.initActionCable();
	}
	initActionCable() {
		window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::AdminDashboardJobsChannel",
			},
			{
				received: (data) => {
					console.log("AdminDashboardJobsChannel: Received data", data);
					if (data.type === "reload") this.reload();
				},
			},
		);
	}
	triggerReload() {
		if (!this.element.classList.contains("remote-rendered")) return;

		console.log("AdminDashboardJobsChannel: Triggering reload");

		$(this.element).trigger("dc:remote:reload");
	}
}

export default AdminDashboardJobsChannel;
