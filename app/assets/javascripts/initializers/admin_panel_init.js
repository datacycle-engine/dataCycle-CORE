const AdminPanel = () => import("../components/admin_panel");
const RebuildClassificationMappings = () =>
	import("../components/rebuild_classification_mappings");

function initAdminPanel(item) {
	AdminPanel().then((mod) => new mod.default(item));
}

function initRebuildClassificationMappings(item) {
	RebuildClassificationMappings().then((mod) => new mod.default(item));
}

export default function () {
	DataCycle.registerAddCallback(
		".formatted-json",
		"admin-panel",
		initAdminPanel.bind(this),
	);

	DataCycle.registerAddCallback(
		".rebuild_classification_mappings",
		"rebuild-classification-mappings",
		initRebuildClassificationMappings.bind(this),
	);

	$(".close-admin-panel").on("click", (event) => {
		event.preventDefault();

		$(event.currentTarget)
			.closest("section#admin-panel")
			.find("ul#admin-icons ")
			.foundation("_collapse");
	});
}
