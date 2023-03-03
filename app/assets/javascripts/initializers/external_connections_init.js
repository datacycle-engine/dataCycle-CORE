import SwitchPrimarySystemButton from '../components/external_connections/switch_primary_system_button';
import AddExternalSystemButton from '../components/external_connections/add_external_system_button';
import RemoveExternalSystemButton from '../components/external_connections/remove_external_system_button';

export default function () {
  DataCycle.initNewElements(
    'a.switch-primary-external-system-link:not(.dcjs-switch-primary-system-button)',
    e => new SwitchPrimarySystemButton(e)
  );

  DataCycle.initNewElements(
    'form.new-external-connection-form:not(.dcjs-add-external-system-button)',
    e => new AddExternalSystemButton(e)
  );

  DataCycle.initNewElements(
    'a.remove-external-system-link:not(.dcjs-remove-external-system-button)',
    e => new RemoveExternalSystemButton(e)
  );
}
