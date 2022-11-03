import Chart from '../components/chart';

export default function () {
  for (const element of document.querySelectorAll('.dc-chart')) new Chart(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('dc-chart') && !e.hasOwnProperty('dcChart'),
    e => new Chart(e)
  ]);
}
