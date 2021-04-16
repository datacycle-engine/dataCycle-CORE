window.DATA_CYCLE_ENGINE_PATH = window.DATA_CYCLE_ENGINE_PATH || '';
window.EDITORSELECTORS = [
  '> .object-browser',
  '> .embedded-object',
  '> input[type=text]',
  '> .editor-block > .quill-editor',
  '> .v-select > select.multi-select',
  '> .v-select > select.single-select',
  '> .v-select > select.async-select',
  '> ul.classification-checkbox-list',
  '> ul.classification-radiobutton-list',
  '> .form-element > .flatpickr-wrapper > input[type=text].flatpickr-input',
  '> .geographic > .geographic-map',
  '> :checkbox',
  '> :radio',
  '> :input[type="number"]',
  '> .duration-slider > div > input[type="number"]'
];

import 'vite/dynamic-import-polyfill';
import jQuery from 'jquery';
import _ from 'lodash';
import Rails from '@rails/ujs';
import ActionCable from 'actioncable';

Object.assign(window, { $: jQuery, jQuery, Rails, _, actionCable: ActionCable.createConsumer() });

import 'jquery-serializejson';
import 'lazysizes';
import 'lazysizes/plugins/unveilhooks/ls.unveilhooks.js';
import './helpers/array_helpers';
import './helpers/number_helpers';
import './helpers/string_helpers';

const initializers = import.meta.glob('./initializers/*.js', { ignore: ['foundation_init.js', 'validation_init.js'] });
import foundationInit from './initializers/foundation_init';
import validationInit from './initializers/validation_init';

export default (() => {
  for (const path in initializers) {
    initializers[path]();
  }

  foundationInit();
  validationInit();

  // try {
  //   Rails.start();
  // } catch (e) {
  //   console.log(e);
  //   console.warn('error starting Rails JS');
  // }

  console.log('initialized...');
})();
