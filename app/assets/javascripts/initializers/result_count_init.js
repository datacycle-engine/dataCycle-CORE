import ResultCount from '../components/result_count';

export default function () {
  for (const count of document.getElementsByClassName('result-count')) {
    new ResultCount(count);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('result-count') && !e.classList.contains('dcjs-result-count'),
    e => new ResultCount(e)
  ]);
}
