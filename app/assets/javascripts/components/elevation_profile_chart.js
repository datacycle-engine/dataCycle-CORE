import { Chart as ChartJs, registerables } from "chart.js";
ChartJs.register(...registerables);
import pick from "lodash/pick";

class ElevationProfileChart {
	constructor(element) {
		this.element = element;
		this.thingId = this.element.dataset.thingId;
		this.datasets = [];
		this.chartLabels;
		this.chartOptions = {
			responsive: true,
			locale: DataCycle.uiLocale,
			elements: {
				point: {
					radius: 1,
					borderWidth: 0,
				},
				line: {
					borderWidth: 2,
				},
			},
			plugins: {
				legend: {
					display: false,
				},
				tooltip: {
					enabled: true,
					callbacks: {
						title: this.formatTooltipTitle.bind(this),
						label: this.formatTooltipLabel.bind(this),
					},
				},
				decimation: {
					enabled: true,
				},
			},
			scales: {
				x: {
					type: "linear",
					ticks: {
						callback: (value) => `${value} m`,
					},
				},
				y: {
					ticks: {
						callback: (value) => `${value} m`,
					},
				},
			},
		};
		this.chartJs;

		this.setup();
	}
	setup() {
		this.initEvents();
		this.updateChartData();
	}
	initEvents() {}
	async initChart() {
		if (!this.chartCanvas) this.renderChartCanvas();
		if (!this.datasets.length) return;

		this.xLabel = await I18n.t("frontend.map.elevation_profile.x_label");
		this.chartJs = new ChartJs(this.chartCanvas, {
			parsing: false,
			normalized: true,
			type: "line",
			data: {
				datasets: this.datasets,
				labels: this.chartLabels,
			},
			options: this.chartOptions,
		});
	}
	renderChartCanvas() {
		this.chartCanvas = document.createElement("canvas");
		this.chartCanvas.className = "dc-chart-canvas";
		this.element.appendChild(this.chartCanvas);
	}
	updateChartData(_event = null) {
		this.fetchAndUpdateChartData()
			.then(() => (this.chartJs ? this.updateChart() : this.initChart()))
			.catch(this.errorHandler.bind(this));
	}
	errorHandler(e) {
		if (this.chartJs) this.chartJs.destroy();
		this.element.textContent = e.message;
	}
	updateChart() {
		this.chartJs.data.datasets = this.datasets;
		this.chartJs.data.labels = this.chartLabels;
		this.chartJs.update();
	}
	formatTooltipLabel(context) {
		return `${context.dataset.label}: ${parseInt(context.parsed.y)} m`;
	}
	formatTooltipTitle(context) {
		return `${this.xLabel}: ${parseInt(context[0].parsed.x)} m`;
	}
	async parseDatasets(datasets) {
		for (let i = 0; i < datasets.length; ++i) {
			datasets[i].type = "line";
			datasets[i].tension = 0.4;
			datasets[i].label = await I18n.t(
				"frontend.map.elevation_profile.y_label",
			);
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
				"tension",
			]);
		}

		return datasets.filter((d) => d.data?.length);
	}
	async parseAndUpdateData(data) {
		let datasets = [];

		if (data?.data) datasets = datasets.concat(data);
		if (data?.datasets) datasets = datasets.concat(data.datasets);
		if (!data)
			throw Error(
				await I18n.t(
					"api_renderer.elevation_profile_renderer.errors.no_elevation_data",
				),
			);

		this.datasets = await this.parseDatasets(datasets);
	}
	async fetchAndUpdateChartData(_event = null) {
		const url = `/things/${this.thingId}/elevation_profile`;
		const formData = new FormData();
		formData.append("dataFormat", "object");
		this.datasets = [];

		const data = await DataCycle.httpRequest(url, {
			method: "POST",
			body: formData,
		}).catch(() => null);

		return this.parseAndUpdateData(data);
	}
}

export default ElevationProfileChart;
