import DomElementHelpers from '../helpers/dom_element_helpers';

const LocalStorageCache = {
  config: {
    ttl: 24 * 3600 * 1000
  },
  set(namespace, key, value, ttl = this.config.ttl) {
    const now = new Date();
    const cache = DomElementHelpers.parseDataAttribute(localStorage.getItem(namespace)) || {};

    cache[key] = { expires: now.getTime() + ttl, value: value };
    localStorage.setItem(namespace, JSON.stringify(cache));

    return cache[key].value;
  },
  get(namespace, key) {
    const cache = DomElementHelpers.parseDataAttribute(localStorage.getItem(namespace));

    if (!cache || !cache.hasOwnProperty(key)) return null;

    const now = new Date();
    if (cache && cache[key] && now.getTime() > cache[key].expires) {
      delete cache[key];
      localStorage.setItem(namespace, JSON.stringify(cache));
      return null;
    }

    return cache[key].value;
  }
};

Object.freeze(LocalStorageCache);

export default LocalStorageCache;
