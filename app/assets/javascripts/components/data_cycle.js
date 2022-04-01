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
        AppSignalFrontEndKey: null,
        retryableHttpCodes: [401, 403, 408, 500, 501, 502, 503, 504, 507, 509]
      },
      config
    );

    this.uiLocale = document.documentElement.lang;
    this.cache = {};

    this.htmlObserver = {
      observer: new MutationObserver(this._observeHtmlContent.bind(this)),
      config: {
        attributes: false,
        characterData: false,
        subtree: true,
        childList: true,
        attributeOldValue: false,
        characterDataOldValue: false
      },
      addCallbacks: [],
      removeCallbacks: []
    };

    this.init();
  }

  init() {
    Object.freeze(this.config);
    this.htmlObserver.observer.observe(document.body, this.htmlObserver.config);
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
  async httpRequest(options = {}) {
    if (this.config.EnginePath && !options.url.includes(this.config.EnginePath))
      options.url = this.joinPath(this.config.EnginePath, options.url);

    const defaultOptions = {
      headers: {
        'X-CSRF-Token': document.getElementsByName('csrf-token')[0].content
      },
      retries: 1,
      retryCount: 3
    };

    const mergedOptions = merge(defaultOptions, options);
    let response;

    try {
      response = await $.ajax(mergedOptions);
    } catch (e) {
      if (!this.config.retryableHttpCodes.includes(e.status) || mergedOptions.retries >= mergedOptions.retryCount)
        throw e;

      mergedOptions.retries++;

      response = await this.httpRequest(mergedOptions);
    }

    return response;
  }
  _prepareElement(element, innerHTML = undefined) {
    if (element instanceof $) element = element[0];
    if (!element) return;

    if (innerHTML != undefined) {
      element.dataset.dcDisableWith = element.dataset.disableWith;
      element.dataset.disableWith = innerHTML;
    } else if (element.dataset.dcDisableWith) {
      element.dataset.disableWith = element.dataset.dcDisableWith;
      delete element.dataset.dcDisableWith;
    }

    if (element.nodeName == 'A' && !element.dataset.disableWith) element.dataset.disableWith = element.innerHTML;
    else if (element.nodeName == 'BUTTON' && !element.dataset.disable && !element.dataset.disableWith)
      element.dataset.disable = true;

    return element;
  }
  disableElement(element, innerHTML = undefined) {
    element = this._prepareElement(element, innerHTML);
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
  _checkForConditionRecursive(node, type) {
    for (let i = 0; i < node.children.length; i++) {
      this._checkForConditionRecursive(node.children[i], type);
    }

    for (let i = 0; i < this.htmlObserver[`${type}Callbacks`].length; ++i) {
      if (this.htmlObserver[`${type}Callbacks`][i][0](node)) this.htmlObserver[`${type}Callbacks`][i][1](node);
    }
  }
  _observeHtmlContent(mutations) {
    for (let i = 0; i < mutations.length; ++i) {
      if (mutations[i].type !== 'childList') continue;

      for (let j = 0; j < mutations[i].addedNodes.length; ++j) {
        if (mutations[i].addedNodes[j].nodeType === Node.ELEMENT_NODE)
          this._checkForConditionRecursive(mutations[i].addedNodes[j], 'add');
      }

      for (let j = 0; j < mutations[i].removedNodes.length; ++j) {
        if (mutations[i].removedNodes[j].nodeType === Node.ELEMENT_NODE)
          this._checkForConditionRecursive(mutations[i].removedNodes[j], 'remove');
      }
    }
  }
}

export default DataCycle;
