import ExifViewer from "../components/tabulator_tables/exif_viewer";
import TableEditor from "../components/tabulator_tables/table_editor";
import TableViewer from "../components/tabulator_tables/table_viewer";

export default function () {
	DataCycle.registerLazyAddCallback(
		"#exif-details",
		"exif-viewer",
		(e) => new ExifViewer(e),
	);

	DataCycle.registerLazyAddCallback(".table-editor", "table-editor", (e) =>
		new TableEditor(e).init(),
	);

	DataCycle.registerLazyAddCallback(".table-viewer", "table-viewer", (e) =>
		new TableViewer(e).init(),
	);
}
