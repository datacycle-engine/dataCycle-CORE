import jQuery from 'jquery';
import Rails from '@rails/ujs';
import ActionCable from '@rails/actioncable';
import DataCycleSingleton from './components/data_cycle';
import I18n from './components/i18n';

Object.assign(window, { $: jQuery, jQuery, Rails, actionCable: ActionCable.createConsumer(), I18n });

import 'jquery-serializejson';
import 'lazysizes';
import 'lazysizes/plugins/unveilhooks/ls.unveilhooks.js';
import './helpers/number_helpers';
import './helpers/string_helpers';

const initializers = import.meta.globEager('./initializers/*.js');
import foundationInit from './initializers/foundation_init';
import validationInit from './initializers/validation_init';
import appSignalInit from './initializers/app_signal_init';
import UrlReplacer from './helpers/url_replacer';

export default (dataCycleConfig = {}) => {
  DataCycle = window.DataCycle = new DataCycleSingleton(dataCycleConfig);

  appSignalInit();

  UrlReplacer.paramsToStoredFilterId();

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
