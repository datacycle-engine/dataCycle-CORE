import AppSignal from '@appsignal/javascript';
import { plugin } from '@appsignal/plugin-window-events';

export default function () {
  if (['production', 'staging'].includes(import.meta.env.MODE) && DataCycle.config.AppSignalFrontEndKey) {
    const appSignal = new AppSignal({
      key: DataCycle.config.AppSignalFrontEndKey
    });

    appSignal.use(plugin());
    window.appSignal = appSignal;
  }
}
