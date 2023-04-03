const AdminPanel = () => import("../components/admin_panel");

function initAdminPanel(item) {
	item.classList.add("dcjs-admin-panel");
	AdminPanel().then((mod) => new mod.default(item));
}

export default function () {
	DataCycle.initNewElements(
		".formatted-json:not(.dcjs-admin-panel)",
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
