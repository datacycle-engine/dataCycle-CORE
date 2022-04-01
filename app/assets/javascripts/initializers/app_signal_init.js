import AppSignal from '@appsignal/javascript';
import { plugin } from '@appsignal/plugin-window-events';

export default function () {
  if (['production', 'staging'].includes(import.meta.env.MODE) && DataCycle.config.AppSignalFrontEndKey) {
    const appSignal = new AppSignal({
      key: DataCycle.config.AppSignalFrontEndKey,
      ignoreErrors: [
        /diff() called with non-document/, // QuillJS Error
        /undefined has no properties/, // QuillJS Error
        /Index or size is negative or greater than the allowed amount/, // QuillJS Error
        /t.domNode[a.DATA_KEY] is undefined/, // QuillJS Error
        /ResizeObserver loop limit exceeded/
      ]
    });

    appSignal.use(plugin());
    window.appSignal = appSignal;
  }
}
