const ChartJs = () => import('chart.js');

class Chart {
  constructor(element) {
    element.dcChart = true;
    const instance = this;
    this.element = element;
    this.inputs = this.element.querySelector('.dc-chart-inputs');
    this.chartTypeInput = this.inputs.querySelector('.dc-chart-chart-type-input');
    this.groupingInput = this.inputs.querySelector('.dc-chart-grouping-input');
    this.timeMinInput = this.inputs.querySelector('.dc-chart-time-min-input');
    this.timeMaxInput = this.inputs.querySelector('.dc-chart-time-max-input');
    this.chartCanvas = this.element.querySelector('canvas.dc-chart-canvas');
    this.container = this.element.closest('.detail-type.timeseries');
    this.thingId = this.container.dataset.thingId;
    this.key = this.container.dataset.key.attributeNameFromKey();
    this.backgroundColor = getComputedStyle(document.documentElement).getPropertyValue('--dark-gray');
    this.datasets = [];
    this.chartLabels;
    this.chartOptions = {
      responsive: true,
      maintainAspectRatio: true,
      locale: DataCycle.uiLocale,
      elements: {
        bar: {
          borderRadius: 999
        }
      },
      plugins: {
        legend: {
          position: 'bottom',
          display: false,
          labels: {
            generateLabels: this.generateChartLabels.bind(this)
          }
        },
        tooltip: {
          enabled: true,
          callbacks: {
            title: function (value) {
              return instance.generateXLabels(value[0].label);
            }
          }
        }
      },
      scales: {
        x: {
          stacked: false,
          grid: {
            display: false
          },
          ticks: {
            callback: function (value, _index, _values) {
              return instance.generateXLabels(this.getLabelForValue(value));
            }
          }
        },
        y: {
          stacked: false,
          grid: {
            drawBorder: false,
            borderDash: [5, 5]
          },
          ticks: {}
        }
      }
    };
    this.chartJs;

    this.setup();
  }
  setup() {
    this.initEvents();
    this.fetchChartData()
      .then(() => this.initChart())
      .catch(e => console.error('Could not init chart:', e));
  }
  initEvents() {
    this.chartTypeInput.addEventListener('change', this.updateChartType.bind(this));
    this.groupingInput.addEventListener('change', this.updateChartData.bind(this));
    this.timeMinInput.addEventListener('change', this.updateChartData.bind(this));
    this.timeMaxInput.addEventListener('change', this.updateChartData.bind(this));
  }
  initChart() {
    if (!this.chartCanvas || !this.datasets.length) return;

    ChartJs().then(({ Chart, registerables }) => {
      Chart.register(...registerables);

      this.chartJs = new Chart(this.chartCanvas, {
        type: this.getChartType(),
        data: {
          datasets: this.datasets,
          labels: this.chartLabels
        },
        options: this.chartOptions
      });
    });
  }
  updateChartData(_event) {
    this.fetchChartData().then(() => this.updateChart());
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
  generateChartLabels(chart) {
    const data = chart.data;

    if (data.datasets.length) {
      let legendEntries = [];

      for (const dataSet of data.datasets) {
        let legendEntry = {
          fillStyle: dataSet.backgroundColor,
          hidden: false,
          index: 0,
          lineWidth: 0,
          strokeStyle: dataSet.backgroundColor,
          text: dataSet.label
        };
        legendEntries.push(legendEntry);
      }

      return legendEntries;
    }
    return [];
  }
  generateXLabels(value) {
    const date = new Date(value);

    switch (this.groupingInput.value) {
      case 'hour':
        return date.toLocaleString([], {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit'
        });
      case 'day':
        return date.toLocaleString([], {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit'
        });
      case 'week':
        return date.toLocaleString([], {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit'
        });
      case 'month':
        return date.toLocaleString([], {
          year: 'numeric',
          month: '2-digit'
        });
      case 'year':
        return date.toLocaleString([], {
          year: 'numeric'
        });
      default:
        return date.toLocaleString([], {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit'
        });
    }
  }
  generateLabels() {
    this.chartLabels = [];

    for (const dataSet of this.datasets) {
      for (const element of dataSet.data) {
        if (!this.chartLabels.includes(element.x)) this.chartLabels.push(element.x);
      }
    }

    this.chartLabels = this.chartLabels.sort((a, b) => {
      return new Date(a) - new Date(b);
    });

    return this.chartLabels;
  }
  getChartType() {
    return this.chartTypeInput.value || 'bar';
  }
  fetchChartData() {
    const url = `/api/v4/things/${this.thingId}/${this.key}`;
    const formData = new FormData();
    formData.append('dataFormat', 'object');
    if (this.groupingInput.value) formData.append(this.groupingInput.name, this.groupingInput.value);
    if (this.timeMinInput.value) formData.append(this.timeMinInput.name, this.timeMinInput.value);
    if (this.timeMaxInput.value) formData.append(this.timeMaxInput.name, this.timeMaxInput.value);
    if (this.timeMaxInput.value) formData.append(this.timeMaxInput.name, this.timeMaxInput.value);

    this.datasets = [];

    const promise = DataCycle.httpRequest({
      method: 'POST',
      url: url,
      data: formData,
      enctype: 'multipart/form-data',
      dataType: 'json',
      processData: false,
      contentType: false,
      cache: false
    });

    promise.then(data => {
      if (data && data.data && data.data.length) {
        this.datasets.push({
          data: data.data,
          type: this.getChartType(),
          backgroundColor: this.backgroundColor
        });
        this.generateLabels();
      }
    });

    return promise;
  }
}

export default Chart;
