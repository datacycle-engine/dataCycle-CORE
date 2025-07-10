const AdminPanel = () => import("../components/admin_panel");

function initAdminPanel(item) {
	AdminPanel().then((mod) => new mod.default(item));
}

export default function () {
	DataCycle.registerAddCallback(
		".formatted-json",
		"admin-panel",
		initAdminPanel.bind(this),
	);

	$(".close-admin-panel").on("click", (event) => {
		event.preventDefault();

		$(event.currentTarget)
			.closest("section#admin-panel")
			.find("ul#admin-icons ")
			.foundation("_collapse");
	});
}
