import merge from 'lodash/merge';

class DataCycle {
  constructor(config = {}) {
    if (DataCycle._instance) return DataCycle._instance;

    DataCycle._instance = this;

    this.config = Object.assign(
      {
        EnginePath: '',
        EditorSelectors: [
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
        ],
        AppSignalFrontEndKey: null
      },
      config
    );

    this.uiLocale = document.documentElement.lang;
    this.cache = {};

    this.newContent = {
      observer: new MutationObserver(this._observeNewContent.bind(this)),
      config: {
        attributes: false,
        characterData: false,
        subtree: true,
        childList: true,
        attributeOldValue: false,
        characterDataOldValue: false
      },
      callbacks: []
    };

    this.init();
  }

  init() {
    Object.freeze(this.config);
    this.newContent.observer.observe(document.body, this.newContent.config);
  }
  joinPath(...segments) {
    const parts = segments.reduce((parts, segment) => {
      if (!segment) return parts;

      if (parts.length > 0) segment = segment.replace(/^\//, '');

      segment = segment.replace(/\/$/, '');

      return parts.concat(segment.split('/'));
    }, []);

    const resultParts = [];

    for (const part of parts) {
      if (part === '.') continue;
      if (part === '..') {
        resultParts.pop();
        continue;
      }

      resultParts.push(part);
    }

    return resultParts.join('/');
  }
  httpRequest(options = {}) {
    if (this.config.EnginePath && !options.url.includes(this.config.EnginePath))
      options.url = this.joinPath(this.config.EnginePath, options.url);

    const defaultOptions = {
      headers: {
        'X-CSRF-Token': document.getElementsByName('csrf-token')[0].content
      }
    };

    return $.ajax(merge(defaultOptions, options));
  }
  _prepareElement(element) {
    if (element instanceof $) element = element[0];
    if (!element) return;

    if (element.nodeName == 'A' && !element.dataset.disableWith) element.dataset.disableWith = element.innerHTML;
    else if (element.nodeName == 'BUTTON' && !element.dataset.disable && !element.dataset.disableWith)
      element.dataset.disable = true;

    return element;
  }
  disableElement(element) {
    element = this._prepareElement(element);
    if (!element) return;

    Rails.disableElement(element);
    if (element.nodeName == 'A') element.classList.add('disabled');
  }
  enableElement(element) {
    element = this._prepareElement(element);
    if (!element) return;

    Rails.enableElement(element);
    if (element.nodeName == 'A') element.classList.remove('disabled');
  }
  async _checkForConditionRecursive(node) {
    for (let i = 0; i < node.children.length; i++) {
      this._checkForConditionRecursive(node.children[i]);
    }

    for (let i = 0; i < this.newContent.callbacks.length; ++i) {
      if (this.newContent.callbacks[i][0](node)) this.newContent.callbacks[i][1](node);
    }
  }
  _observeNewContent(mutations) {
    for (let i = 0; i < mutations.length; ++i) {
      if (mutations[i].type !== 'childList') continue;

      for (let j = 0; j < mutations[i].addedNodes.length; ++j) {
        if (mutations[i].addedNodes[j].nodeType === Node.ELEMENT_NODE)
          this._checkForConditionRecursive(mutations[i].addedNodes[j]);
      }
    }
  }
}

export default DataCycle;
