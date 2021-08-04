import template from 'lodash/template';

const I18n = {
  cache: {},
  async translate(path, substitutions = {}) {
    let text = this.cache[path];

    if (!text) text = await this._loadTranslation(path);

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
      console.error(e);
    });

    return (this.cache[path] = result.text);
  }
};

Object.freeze(I18n);

export default I18n;
