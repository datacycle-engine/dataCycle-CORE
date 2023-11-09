const AdminPanel = () => import("../components/admin_panel");
const RebuildClassificationMappings = () =>
	import("../components/rebuild_classification_mappings");

function initAdminPanel(item) {
	item.classList.add("dcjs-admin-panel");
	AdminPanel().then((mod) => new mod.default(item));
}

function initRebuildClassificationMappings(item) {
	item.classList.add("dcjs-rebuild-classification-mappings");
	RebuildClassificationMappings().then((mod) => new mod.default(item));
}

export default function () {
	DataCycle.initNewElements(
		".formatted-json:not(.dcjs-admin-panel)",
		initAdminPanel.bind(this),
	);

	DataCycle.initNewElements(
		".rebuild_classification_mappings:not(.dcjs-rebuild-classification-mappings)",
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
