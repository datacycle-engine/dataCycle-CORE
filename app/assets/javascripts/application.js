import 'vite/dynamic-import-polyfill';
import jQuery from 'jquery';
import _ from 'lodash';
import Rails from '@rails/ujs';
import ActionCable from 'actioncable';
import DataCycle from './components/data_cycle';

Object.assign(window, { $: jQuery, jQuery, Rails, _, actionCable: ActionCable.createConsumer(), DataCycle });

import 'jquery-serializejson';
import 'lazysizes';
import 'lazysizes/plugins/unveilhooks/ls.unveilhooks.js';
import './helpers/array_helpers';
import './helpers/number_helpers';
import './helpers/string_helpers';

const initializers = import.meta.globEager('./initializers/*.js');
import foundationInit from './initializers/foundation_init';
import validationInit from './initializers/validation_init';

export default (() => {
  for (const path in initializers) {
    if (!path.includes('foundation_init') && !path.includes('validation_init')) {
      try {
        initializers[path].default();
      } catch (err) {
        console.log(err);
      }
    }
  }

  foundationInit();
  validationInit();

  console.log('initialized...');
})();
