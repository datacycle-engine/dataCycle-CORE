import template from "lodash/template";
import get from "lodash/get";
import LocalStorageCache from "./local_storage_cache";

const I18n = {
	config: {
		namespace: "dcI18nCache",
		version: document.documentElement.dataset.i18nDigest,
	},
	countMapping(count) {
		if (count === 0) return "zero";
		if (count === 1) return "one";
		return "other";
	},
	async translate(path, substitutions = {}) {
		let text = LocalStorageCache.get(
			this.config.namespace,
			path,
			this.config.version,
		);
		if (text && typeof text.then === "function") text = await text;

		const promiseKey = `${this.config.namespace}/${path}`;
		if (!text) {
			const result = DataCycle.globalPromises[promiseKey]
				? await DataCycle.globalPromises[promiseKey]
				: await this._loadTranslation(path);
			if (result && !result.error && Object.hasOwn(result, "text"))
				text = LocalStorageCache.set(
					this.config.namespace,
					path,
					result.text,
					this.config.version,
				);
			else if (
				Object.hasOwn(result, "error") &&
				Object.hasOwn(substitutions, "default")
			)
				text = LocalStorageCache.set(
					this.config.namespace,
					path,
					substitutions.default,
					this.config.version,
				);
			else
				text = Object.hasOwn(result, "error")
					? result.error
					: this._errorObject(path).error;
		}

		if (
			text &&
			typeof text === "object" &&
			Object.hasOwn(substitutions, "count")
		)
			text = text[this.countMapping(substitutions.count)];

		const compiled = template(text, { interpolate: /%{([\s\S]+?)}/g });

		return compiled(substitutions);
	},
	_errorObject(path, e = {}) {
		return { error: get(e, "responseJSON.error", path) };
	},
	async _loadTranslation(path) {
		const promise = DataCycle.httpRequest(
			"/i18n/translate",
			{
				body: {
					path: path,
				},
			},
			0,
		).catch((e) => this._errorObject(path, e));

		const promiseKey = `${this.config.namespace}/${path}`;
		DataCycle.globalPromises[promiseKey] = promise;

		const result = await promise;
		DataCycle.globalPromises[promiseKey] = undefined;

		return result;
	},
};

I18n.t = I18n.translate;

Object.freeze(I18n);

export default I18n;
