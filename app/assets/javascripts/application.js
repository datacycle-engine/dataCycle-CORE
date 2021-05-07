import 'vite/dynamic-import-polyfill';
import jQuery from 'jquery';
import Rails from '@rails/ujs';
import ActionCable from 'actioncable';
import DataCycle from './components/data_cycle';

Object.assign(window, { $: jQuery, jQuery, Rails, actionCable: ActionCable.createConsumer(), DataCycle });

import 'jquery-serializejson';
import 'lazysizes';
import 'lazysizes/plugins/unveilhooks/ls.unveilhooks.js';
import './helpers/number_helpers';
import './helpers/string_helpers';

const initializers = import.meta.globEager('./initializers/*.js');
import foundationInit from './initializers/foundation_init';
import validationInit from './initializers/validation_init';
import appSignalInit from './initializers/app_signal_init';

export default (dataCycleConfig = {}) => {
  DataCycle.init(dataCycleConfig);

  appSignalInit();

  $(function () {
    for (const path in initializers) {
      if (!path.includes('foundation_init') && !path.includes('validation_init') && !path.includes('app_signal_init')) {
        try {
          initializers[path].default();
        } catch (err) {
          console.error(err);
          if (window.appSignal) appSignal.sendError(err);
        }
      }
    }

    foundationInit();
    validationInit();
  });
};
