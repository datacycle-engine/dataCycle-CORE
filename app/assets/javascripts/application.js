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
import UrlReplacer from './helpers/url_replacer';

export default (dataCycleConfig = {}, postDataCycleInit = null) => {
  DataCycle = window.DataCycle = new DataCycleSingleton(dataCycleConfig);

  UrlReplacer.paramsToStoredFilterId();

  if (typeof postDataCycleInit === 'function') postDataCycleInit();
  DataCycle.notifications.addEventListener('error', ({ detail }) => console.error(detail));

  $(function () {
    for (const path in initializers) {
      if (!path.includes('foundation_init') && !path.includes('validation_init') && !path.includes('app_signal_init')) {
        try {
          initializers[path].default();
        } catch (err) {
          DataCycle.notifications.dispatchEvent(new CustomEvent('error', { detail: err }));
        }
      }
    }

    foundationInit();
    validationInit();
  });
};
