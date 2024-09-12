import DomElementHelpers from "../helpers/dom_element_helpers";

const LocalStorageCache = {
	cachedNamespace(namespace) {
		return DomElementHelpers.parseDataAttribute(
			localStorage.getItem(namespace),
		);
	},
	set(namespace, key, value, version = 0) {
		const cache = this.cachedNamespace(namespace) || {};

		cache[key] = { version: version, value: value };
		localStorage.setItem(namespace, JSON.stringify(cache));

		return cache[key].value;
	},
	get(namespace, key, version = 0) {
		const cache = this.cachedNamespace(namespace);

		if (!cache || !Object.hasOwn(cache, key)) return null;

		if (cache?.[key] && cache[key].version !== version) {
			delete cache[key];
			localStorage.setItem(namespace, JSON.stringify(cache));
			return null;
		}

		return cache[key].value;
	},
};

Object.freeze(LocalStorageCache);

export default LocalStorageCache;
