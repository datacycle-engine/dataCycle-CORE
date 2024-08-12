const Tabulator = () => import("tabulator-tables");

class TableEditor {
	constructor(element) {
		this.element = element;
		this.key = this.element.dataset.key;

		this.init();
	}
	init() {
		this.initTabulator();
	}
	initTabulator() {
		// const objectArray = Object.entries(this.value);
		// const transformedTableData = objectArray.map(([key, value]) => {
		// 	return { name: key, value: value };
		// });

		Tabulator().then(({ Tabulator }) => {
			new Tabulator(this.element, {
				locale: DataCycle.uiLocale,
				data: [],
				layout: "fitColumns", //fit columns to width of table (optional)
				autoColumns: true,
				movableColumns: true,
				movableRows: true,
			});
		});
	}
}

export default TableEditor;
