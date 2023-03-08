import { Chart as ChartJs, registerables } from "chart.js";
import "chartjs-adapter-luxon";
ChartJs.register(...registerables);
import pick from "lodash/pick";
import capitalize from "lodash/capitalize";

class Chart {
	constructor(element) {
		this.element = element;
		this.inputs = this.element.querySelector(".dc-chart-inputs");
		this.chartTypeInput = this.inputs.querySelector(
			".dc-chart-chart-type-input",
		);
		this.groupingInput = this.inputs.querySelector(".dc-chart-grouping-input");
		this.timeMinInput = this.inputs.querySelector(".dc-chart-time-min-input");
		this.timeMaxInput = this.inputs.querySelector(".dc-chart-time-max-input");
		this.chartCanvas = this.element.querySelector("canvas.dc-chart-canvas");
		this.container = this.element.closest(".detail-type.timeseries");
		this.thingId = this.container.dataset.thingId;
		this.key = this.container.dataset.key.attributeNameFromKey();
		this.datasets = [];
		this.chartLabels;
		this.chartOptions = {
			responsive: true,
			maintainAspectRatio: true,
			locale: DataCycle.uiLocale,
			elements: {
				point: {
					radius: 3,
					borderWidth: 0,
				},
				line: {
					borderWidth: 2,
				},
				bar: {
					borderRadius: 999,
					borderWidth: 0,
				},
			},
			plugins: {
				legend: {
					position: "right",
					display: true,
				},
				tooltip: {
					enabled: true,
					callbacks: {
						title: this.formatTooltipTitle.bind(this),
					},
				},
			},
			scales: {
				x: {
					type: "time",
					grid: {
						display: false,
					},
					title: {
						display: false,
					},
					time: {
						minUnit: "second",
					},
				},
				y: {
					grid: {
						drawBorder: false,
						borderDash: [5, 5],
					},
				},
			},
		};
		this.timeFormats = {
			default: {},
			year: { year: "numeric" },
			quarter: { year: "numeric", month: "numeric" },
			month: { year: "numeric", month: "short" },
			week: { dateStyle: "medium" },
			day: { dateStyle: "medium" },
			hour: {
				year: "numeric",
				month: "short",
				day: "numeric",
				hour: "numeric",
			},
			hour_of_day: { hour: "numeric" },
		};
		this.chartJs;

		this.setup();
	}
	setup() {
		this.initEvents();
		this.updateChartData();
	}
	initEvents() {
		this.chartTypeInput.addEventListener(
			"change",
			this.updateChartType.bind(this),
		);
		this.groupingInput.addEventListener(
			"change",
			this.updateChartData.bind(this),
		);
		this.timeMinInput.addEventListener(
			"change",
			this.updateChartData.bind(this),
		);
		this.timeMaxInput.addEventListener(
			"change",
			this.updateChartData.bind(this),
		);
	}
	initChart() {
		if (!(this.chartCanvas && this.datasets.length)) return;

		this.chartJs = new ChartJs(this.chartCanvas, {
			parsing: false,
			normalized: true,
			type: this.getChartType(),
			data: {
				datasets: this.datasets,
				labels: this.chartLabels,
			},
			options: this.chartOptions,
		});
	}
	updateChartData(_event = null) {
		this.fetchAndUpdateChartData()
			.then(() => (this.chartJs ? this.updateChart() : this.initChart()))
			.catch(this.errorHandler.bind(this));
	}
	errorHandler(e) {
		if (this.chartJs) this.chartJs.destroy();
		console.error("Could not init chart:", e);
	}
	updateChartType(_event) {
		for (const dataSet of this.datasets) {
			dataSet.type = this.getChartType();
		}

		this.updateChart();
	}
	updateChart() {
		this.chartJs.data.datasets = this.datasets;
		this.chartJs.data.labels = this.chartLabels;
		this.chartJs.update();
	}
	formatTooltipTitle(context) {
		const scaleUnit =
			this.scaleXKey ||
			context[0].chart.config.options.scales.x.time.minUnit ||
			"default";
		const date = new Date(context[0].parsed.x);

		return date.toLocaleString([], this.timeFormats[scaleUnit]);
	}
	getChartType() {
		return this.chartTypeInput.value || "bar";
	}
	async parseDatasets(datasets) {
		for (let i = 0; i < datasets.length; ++i) {
			if (datasets[i].meta?.label)
				datasets[i].label = await I18n.t(
					`timeseries.chart_labels.${datasets[i].meta.label}`,
					{
						default: capitalize(datasets[i].meta.label),
					},
				);

			datasets[i].type = this.getChartType();
			datasets[i].backgroundColor = getComputedStyle(
				document.documentElement,
			).getPropertyValue(`--chart${i}`);
			datasets[i].borderColor = datasets[i].backgroundColor;
			datasets[i].fill = false;

			datasets[i] = pick(datasets[i], [
				"data",
				"label",
				"type",
				"backgroundColor",
				"borderColor",
				"fill",
			]);
		}

		return datasets.filter((d) => d.data?.length);
	}
	async parseAndUpdateData(data) {
		let datasets = [];

		if (data?.data) datasets = datasets.concat(data);
		if (data?.datasets) datasets = datasets.concat(data.datasets);

		if (data.meta?.label_x) {
			this.chartOptions.scales.x.title.display = true;
			this.scaleXKey = data.meta.label_x;
			this.chartOptions.scales.x.title.text = await I18n.t(
				`timeseries.axe_labels.${data.meta.label_x}`,
				{
					default: capitalize(data.meta.label_x),
				},
			);
		} else {
			this.chartOptions.scales.x.title.display = false;
			this.scaleXKey = null;
			this.chartOptions.scales.x.title.text = "";
		}

		if (data.meta?.scale_x)
			this.chartOptions.scales.x.time.minUnit = data.meta.scale_x;
		else this.chartOptions.scales.x.time.minUnit = "second";

		this.datasets = await this.parseDatasets(datasets);
		this.chartOptions.plugins.legend.display = this.datasets.some(
			(d) => d.label,
		);
	}
	disableForm() {
		this.element.classList.add("data-loading");

		this.groupingInput.disabled = true;
		this.chartTypeInput.disabled = true;
		for (const datepicker of this.inputs.querySelectorAll(
			".flatpickr-wrapper .flatpickr-input",
		))
			datepicker.disabled = true;
	}
	enableForm() {
		this.element.classList.remove("data-loading");

		this.groupingInput.disabled = false;
		this.chartTypeInput.disabled = false;
		for (const datepicker of this.inputs.querySelectorAll(
			".flatpickr-wrapper .flatpickr-input",
		))
			datepicker.disabled = false;
	}
	async fetchAndUpdateChartData(_event = null) {
		this.disableForm();

		const url = `/api/v4/things/${this.thingId}/${this.key}`;
		const formData = new FormData();
		formData.append("dataFormat", "object");
		if (this.groupingInput.value)
			formData.append(this.groupingInput.name, this.groupingInput.value);
		if (this.timeMinInput.value)
			formData.append(this.timeMinInput.name, this.timeMinInput.value);
		if (this.timeMaxInput.value)
			formData.append(this.timeMaxInput.name, this.timeMaxInput.value);
		if (this.timeMaxInput.value)
			formData.append(this.timeMaxInput.name, this.timeMaxInput.value);

		this.datasets = [];

		const data = await DataCycle.httpRequest(url, {
			method: "POST",
			body: formData,
		}).catch(() => null);

		await this.parseAndUpdateData(data);

		this.enableForm();
	}
}

export default Chart;
