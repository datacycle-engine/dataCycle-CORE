import GravityUiEditor from '../components/gravity_ui_editor';

export default function () {
  DataCycle.initNewElements(
    'button.button.change-gravity-ui:not(.dcjs-gravity-ui-editor)',
    e => new GravityUiEditor(e)
  );
}
