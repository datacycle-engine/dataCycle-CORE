const TabulatorLoader = () => import("tabulator-tables");
import DomElementHelpers from "../../helpers/dom_element_helpers";

class TableViewer {
	constructor(element) {
		this.element = element;
		this.key = this.element.dataset.key;
		this.table;
		this.value = DomElementHelpers.parseDataAttribute(
			this.element.dataset.value,
		);
		this.data = [];
		this.tabulatorConfig = {
			locale: DataCycle.uiLocale,
			data: this.data,
			layout: "fitColumns",
			autoColumns: true,
		};
	}
	loadInitialData() {
		const data = this.value || [];

		if (data.length) this.data.push(...this.arrayToData(data));

		return this.data;
	}
	arrayToData(array) {
		if (!array.length) return [];

		const columns = array.shift();
		const data = [];

		for (const row of array) {
			data.push(
				Object.fromEntries(
					columns.map((column, index) => [column, row[index]]),
				),
			);
		}

		return data;
	}
	init() {
		TabulatorLoader().then(({ Tabulator }) => {
			this.loadInitialData();
			const table = new Tabulator(this.element, this.tabulatorConfig);

			table.on("tableBuilt", () => {
				this.table = table;
			});
		});
	}
}

export default TableViewer;
