import DomElementHelpers from "../../helpers/dom_element_helpers";
const Tabulator = () => import("tabulator-tables");

class ExifViewer {
	constructor(element) {
		this.element = element;
		this.value = DomElementHelpers.parseDataAttribute(
			this.element.dataset.exif,
		);

		this.init();
	}
	init() {
		if (this.value === undefined) return;

		this.initTabulator();
	}
	initTabulator() {
		const objectArray = Object.entries(this.value);
		const transformedTableData = objectArray.map(([key, value]) => {
			return { name: key, value: value };
		});

		Tabulator().then(({ TabulatorFull }) => {
			new TabulatorFull(this.element, {
				data: transformedTableData,
				layout: "fitColumns", //fit columns to width of table (optional)
				columns: [
					//Define Table Columns
					{ title: "Name", field: "name" },
					{ title: "Wert", field: "value" },
				],
				initialSort: [
					{ column: "name", dir: "asc" }, //sort by this first
				],
			});
		});
	}
}

export default ExifViewer;
