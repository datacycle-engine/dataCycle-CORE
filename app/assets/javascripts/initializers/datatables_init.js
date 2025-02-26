const DataTables = () => import("datatables.net-zf").then((mod) => mod.default);

class ActivityList {
	constructor(
		item,
		options = {
			ajax: "/admin/activity_details/summary",
			lengthChange: true,
			columns: [
				{ title: "Activity", data: "activity_type" },
				{ title: "Count", data: "data_count" },
			],
			order: [[1, "desc"]],
		},
	) {
		this.item = item;
		this.options = options;
		this.dataTable;

		this.setup();
	}
	setup() {
		DataTables().then(() => {
			this.dataTable = $(this.item).DataTable(this.options);
		});
	}
}

class ActivityUserList extends ActivityList {
	constructor(item) {
		super(item, {
			ajax: "/admin/activity_details/user_summary",
			lengthChange: true,
			columns: [
				{ title: "User", data: "user_id" },
				{ title: "E-Mail", data: "email" },
				{ title: "Activity", data: "activity_type" },
				{ title: "Count", data: "data_count" },
			],
			order: [[3, "desc"]],
		});
	}
}

class ActivityDetails extends ActivityList {
	constructor(item) {
		super(item, {
			ajax: "/admin/activity_details/details",
			lengthChange: true,
			columns: [
				{ title: "User", data: "user_id" },
				{ title: "E-Mail", data: "email" },
				{ title: "Activity", data: "activity_type" },
				{ title: "Last Request", data: "last_request" },
				{ title: "Controller", data: "request_controller" },
				{ title: "Action", data: "request_action" },
				{ title: "Type", data: "request_type" },
				{ title: "Include", data: "request_include" },
				{ title: "Fields", data: "request_fields" },
				{ title: "Filter", data: "request_filter" },
				{ title: "Page", data: "request_page" },
				{ title: "Mode", data: "request_mode" },
				{ title: "Id", data: "request_id" },
				{ title: "Referer", data: "request_referer" },
				{ title: "Origin", data: "request_origin" },
				{ title: "Middleware-Origin", data: "request_middleware_origin" },
				{ title: "Widget-Identifier", data: "request_widget_identifier" },
				{ title: "Widget-Type", data: "request_widget_type" },
				{ title: "Widget-Version", data: "request_widget_version" },
				{ title: "Count", data: "data_count" },
			],
			order: [[10, "desc"]],
		});
	}
}

export default function () {
	DataCycle.registerAddCallback(
		"#activity_list",
		"data-table",
		(e) => new ActivityList(e),
	);
	DataCycle.registerAddCallback(
		"#activity_user_list",
		"data-table",
		(e) => new ActivityUserList(e),
	);
	DataCycle.registerAddCallback(
		"#activity_details",
		"data-table",
		(e) => new ActivityDetails(e),
	);
}
