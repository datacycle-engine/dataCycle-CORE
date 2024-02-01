import GravityUiSelector from '../components/gravity_ui_selector';

export default function () {
  DataCycle.initNewElements(
    'button.button.change-gravity-ui:not(.dcjs-gravity-ui-selector)',
    e => new GravityUiSelector(e)
  );
}
