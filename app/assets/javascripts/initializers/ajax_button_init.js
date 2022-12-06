import LifeCylceButton from '../components/ajax_buttons/life_cycle_buttons';

export default function () {
  for (const element of document.querySelectorAll('a.content-pool-button')) new LifeCylceButton(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.nodeName === 'A' && e.classList.contains('content-pool-button') && !e.hasOwnProperty('dcLifeCylceButton'),
    e => new LifeCylceButton(e)
  ]);
}
