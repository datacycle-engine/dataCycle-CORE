import template from 'lodash/template';
import get from 'lodash/get';
import LocalStorageCache from './local_storage_cache';

const I18n = {
  config: {
    namespace: 'dcI18nCache'
  },
  countMapping(count) {
    if (count === 0) return 'zero';
    else if (count === 1) return 'one';
    else return 'other';
  },
  async translate(path, substitutions = {}) {
    let text = LocalStorageCache.get(this.config.namespace, path);
    if (text && typeof text.then === 'function') text = await text;

    const promiseKey = `${this.config.namespace}/${path}`;
    if (!text) {
      const result = DataCycle.globalPromises.hasOwnProperty(promiseKey)
        ? await DataCycle.globalPromises[promiseKey]
        : await this._loadTranslation(path);
      if (result && !result.error && result.hasOwnProperty('text'))
        text = LocalStorageCache.set(this.config.namespace, path, result.text);
      else text = result.hasOwnProperty('error') ? result.error : this._errorObject(path).error;
    }

    if (text && typeof text === 'object' && substitutions.hasOwnProperty('count'))
      text = text[this.countMapping(substitutions.count)];

    const compiled = template(text, { interpolate: /%{([\s\S]+?)}/g });

    return compiled(substitutions);
  },
  _errorObject(path, e = {}) {
    return { error: get(e, 'responseJSON.error', path) };
  },
  async _loadTranslation(path) {
    const promise = DataCycle.httpRequest({
      url: '/i18n/translate',
      contentType: 'application/json',
      data: {
        path: path
      }
    }).catch(e => this._errorObject(path, e));

    const promiseKey = `${this.config.namespace}/${path}`;
    DataCycle.globalPromises[promiseKey] = promise;

    const result = await promise;
    delete DataCycle.globalPromises[promiseKey];

    return result;
  }
};

I18n.t = I18n.translate;

Object.freeze(I18n);

export default I18n;
