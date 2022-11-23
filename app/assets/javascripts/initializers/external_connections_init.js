import SwitchPrimarySystemButton from '../components/external_connections/switch_primary_system_button';
import AddExternalSystemButton from '../components/external_connections/add_external_system_button';
import RemoveExternalSystemButton from '../components/external_connections/remove_external_system_button';

export default function () {
  for (const element of document.querySelectorAll('a.switch-primary-external-system-link'))
    new SwitchPrimarySystemButton(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.nodeName == 'A' &&
      e.classList.contains('switch-primary-external-system-link') &&
      !e.hasOwnProperty('dcSwitchPrimarySystemButton'),
    e => new SwitchPrimarySystemButton(e)
  ]);

  for (const element of document.querySelectorAll('form.new-external-connection-form'))
    new AddExternalSystemButton(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.nodeName == 'FORM' &&
      e.classList.contains('new-external-connection-form') &&
      !e.hasOwnProperty('dcAddExternalSystemButton'),
    e => new AddExternalSystemButton(e)
  ]);

  for (const element of document.querySelectorAll('a.remove-external-system-link'))
    new RemoveExternalSystemButton(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.nodeName == 'A' &&
      e.classList.contains('remove-external-system-link') &&
      !e.hasOwnProperty('dcRemoveExternalSystemButton'),
    e => new RemoveExternalSystemButton(e)
  ]);
}
