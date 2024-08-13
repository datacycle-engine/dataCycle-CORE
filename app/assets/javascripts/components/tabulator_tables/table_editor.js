const TabulatorLoader = () => import("tabulator-tables");
import DomElementHelpers from "../../helpers/dom_element_helpers";
import TableViewer from "./table_viewer";

class TableEditor extends TableViewer {
	constructor(element) {
		super(element);
		this.formElement = this.element.closest(".form-element.table");
		this.hiddenField = this.formElement.querySelector(
			`input[type=hidden][name="${this.key}"]`,
		);
		this.editable = this.hiddenField && !this.hiddenField.disabled;
		this.uploadButton = this.formElement.querySelector(
			"button.table-data-upload",
		);
		this.headerMenu = [
			{
				label: '<i class="fa fa-trash"></i>',
				action: this.deleteColumn.bind(this),
			},
		];
		this.columnDefinition = {
			editor: "input",
			editableTitle: true,
			cssClass: "table-editor-movable-column",
			headerMenu: this.headerMenu,
			sorter: "string",
		};

		this.value = DomElementHelpers.parseDataAttribute(this.hiddenField.value);
		this.excludedDataColumns = ["dcjs_delete_column"];
		this.index = 0;
		this.tabulatorEditorConfig = {
			...this.tabulatorConfig,
			autoColumnsDefinitions: this.autoColumnsDefinitions.bind(this),
			movableColumns: true,
			movableRows: true,
			tabEndNewRow: true,
			rowHeader: {
				headerSort: false,
				resizable: false,
				minWidth: 30,
				width: 30,
				rowHandle: true,
				formatter: this.handleFormatter.bind(this),
			},
			footerElement:
				'<button type="button" class="table-editor-add-row"><i class="fa fa-plus"></i></button>',
		};
	}
	autoColumnsDefinitions(definitions) {
		for (const column of definitions) {
			Object.assign(column, this.columnDefinition);
		}

		return definitions;
	}
	updateHiddenValue() {
		if (!this.table) return;

		const columns = this.table
			.getColumnDefinitions()
			.filter(
				(column) =>
					column.field && !this.excludedDataColumns.includes(column.field),
			);
		const tableData = this.table.getData();
		const array = [columns.map((column) => column.title)];
		for (const row of tableData) {
			array.push(columns.map((column) => row[column.field]));
		}

		this.hiddenField.value = JSON.stringify(array);
	}
	addRow() {
		if (!this.table) return;

		this.table.addRow({});
	}
	init() {
		TabulatorLoader().then(
			({
				Tabulator,
				EditModule,
				FormatModule,
				InteractionModule,
				KeybindingsModule,
				MoveColumnsModule,
				MoveRowsModule,
				MenuModule,
				ImportModule,
			}) => {
				Tabulator.registerModule([
					EditModule,
					FormatModule,
					InteractionModule,
					KeybindingsModule,
					MoveColumnsModule,
					MoveRowsModule,
					MenuModule,
					ImportModule,
				]);
				this.loadInitialData();
				const config = this.editable
					? this.tabulatorEditorConfig
					: this.tabulatorConfig;
				const table = new Tabulator(this.element, config);

				table.on("tableBuilt", () => {
					this.table = table;
					if (this.editable) this.postInit();
				});

				if (this.editable) this.addTableEventHandlers(table);
			},
		);
	}
	addTableEventHandlers(table) {
		table.on("columnTitleChanged", this.updateHiddenValue.bind(this));
		table.on("dataChanged", this.updateHiddenValue.bind(this));
		table.on("columnMoved", this.updateHiddenValue.bind(this));
		table.on("rowMoved", this.updateHiddenValue.bind(this));
		table.on("dataProcessed", this.dataProcessed.bind(this, table));
	}
	handleFormatter(cell) {
		const element = cell.getElement();
		element.classList.add("table-editor-row-handle");

		return '<i class="fa fa-bars"></i>';
	}
	dataProcessed(table) {
		table.addColumn({
			title: '<i class="fa fa-plus"></i>',
			field: "dcjs_delete_column",
			formatter: this.initDeleteRowButton.bind(this),
			minWidth: 30,
			width: 30,
			align: "center",
			resizable: false,
			headerSort: false,
			cssClass: "table-editor-delete-row",
			cellClick: this.deleteRow.bind(this),
			headerClick: this.addColumn.bind(this),
		});

		this.updateHiddenValue();
	}
	postInit() {
		this.addEventHandlers();
	}
	initDeleteRowButton() {
		return '<i class="fa fa-trash"></i>';
	}
	deleteRow(_e, cell) {
		cell.getRow().delete();
	}
	addColumn() {
		if (!this.table) return;

		this.index++;

		this.table.addColumn(
			{
				title: `Spalte ${this.index}`,
				field: `Spalte ${this.index}`,
				...this.columnDefinition,
			},
			true,
			"dcjs_delete_column",
		);
	}
	deleteColumn(_e, cell) {
		cell.delete();
	}
	uploadData(e) {
		e.preventDefault();
		e.stopPropagation();

		this.table.import("csv", ".csv");
	}
	addEventHandlers() {
		this.addButton = this.table.footerManager.element.querySelector(
			".table-editor-add-row",
		);

		if (this.addButton) {
			this.addButton.addEventListener("click", this.addRow.bind(this));
		}

		if (this.uploadButton) {
			this.uploadButton.disabled = false;
			this.uploadButton.addEventListener("click", this.uploadData.bind(this));
		}
	}
}

export default TableEditor;
