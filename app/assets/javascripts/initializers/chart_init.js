const Chart = () => import('../components/chart');

function initChartJs(element) {
  element.classList.add('dcjs-chart');
  Chart().then(mod => new mod.default(element));
}

export default function () {
  for (const element of document.querySelectorAll('.dc-chart')) initChartJs(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('dc-chart') && !e.classList.contains('dcjs-chart'),
    e => initChartJs(e)
  ]);
}
