import template from 'lodash/template';
import get from 'lodash/get';

const I18n = {
  cache: {},
  countMapping(count) {
    if (count === 0) return 'zero';
    else if (count === 1) return 'one';
    else return 'other';
  },
  async translate(path, substitutions = {}) {
    let text = this.cache[path];
    if (text && typeof text.then === 'function') text = await text;

    if (!text) {
      this.cache[path] = this._loadTranslation(path);
      text = this.cache[path] = await this.cache[path];
    }

    if (text && typeof text === 'object' && substitutions.hasOwnProperty('count'))
      text = text[this.countMapping(substitutions.count)];

    const compiled = template(text, { interpolate: /%{([\s\S]+?)}/g });

    return compiled(substitutions);
  },
  async _loadTranslation(path) {
    const result = await DataCycle.httpRequest({
      url: '/i18n/translate',
      contentType: 'application/json',
      data: {
        path: path
      }
    }).catch(e => {
      return { text: `${get(e, 'responseJSON.error', 'TRANSLATION_MISSING')} (${path})` };
    });

    return result.text;
  }
};

Object.freeze(I18n);

export default I18n;
