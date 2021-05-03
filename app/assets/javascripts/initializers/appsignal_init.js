import Appsignal from '@appsignal/javascript';
import { plugin } from '@appsignal/plugin-window-events';

export default function () {
  if (['production', 'staging'].includes(import.meta.env.MODE) && DataCycle.config.AppSignalFrontEndKey) {
    const appsignal = new Appsignal({
      key: DataCycle.config.AppSignalFrontEndKey
    });

    appsignal.use(plugin());
    window.appsignal = appsignal;
  }
}
