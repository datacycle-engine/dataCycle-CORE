const Chart = () => import('../components/chart');

export default function () {
  for (const element of document.querySelectorAll('.dc-chart')) Chart().then(mod => new mod.default(element));
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('dc-chart') && !e.classList.contains('dcjs-chart'),
    e => Chart().then(mod => new mod.default(e))
  ]);
}
