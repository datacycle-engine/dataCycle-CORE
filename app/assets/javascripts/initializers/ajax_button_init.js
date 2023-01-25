import LifeCylceButton from '../components/ajax_buttons/life_cycle_buttons';

export default function () {
  DataCycle.initNewElements('a.content-pool-button:not(.dcjs-life-cycle-button)', e => new LifeCylceButton(e));
}
