import ObserverHelpers from "../helpers/observer_helpers";

class DataCycle {
	constructor(config = {}) {
		// rome-ignore lint/correctness/noConstructorReturn: <explanation>
		if (DataCycle._instance) return DataCycle._instance;

		DataCycle._instance = this;

		this.config = Object.assign(
			{
				EnginePath: "",
				EditorSelectors: [
					"> .object-browser",
					"> .embedded-object",
					"> input[type=text]",
					"> .editor-block > .quill-editor",
					"> .v-select > select.multi-select",
					"> .v-select > select.single-select",
					"> .v-select > select.async-select",
					"> ul.classification-checkbox-list",
					"> ul.classification-radiobutton-list",
					"> .form-element > .flatpickr-wrapper > input[type=text].flatpickr-input",
					"> .geographic > .geographic-map",
					"> :checkbox",
					"> :radio",
					'> :input[type="number"]',
					'> .duration-slider > div > input[type="number"]',
				],
				retryableHttpCodes: [401, 403, 408, 500, 501, 502, 503, 504, 507, 509],
				remoteRenderFull: false,
			},
			config,
		);

		this.uiLocale = document.documentElement.lang;
		this.globalPromises = {};

		this.htmlObserver = {
			observer: new MutationObserver(this._addToCallbackQueue.bind(this)),
			addCallbacks: [],
			removeCallbacks: [],
		};

		this.notifications = new Comment("dataCycle-notifications");
		this.mutableNodes = ["A", "BUTTON"];
		this.callbackQueue = [];

		this.init();
	}

	init() {
		Object.freeze(this.config);
		this.htmlObserver.observer.observe(
			document.body,
			ObserverHelpers.newItemsConfig,
		);
	}
	joinPath(...segments) {
		const parts = segments.reduce((parts, segment) => {
			if (!segment) return parts;

			let s = segment;

			if (parts.length > 0) s = s.replace(/^\//, "");

			s = s.replace(/\/$/, "");

			return parts.concat(s.split("/"));
		}, []);

		const resultParts = [];

		for (const part of parts) {
			if (part === ".") continue;
			if (part === "..") {
				resultParts.pop();
				continue;
			}

			resultParts.push(part);
		}

		return resultParts.join("/");
	}
	wait(delay) {
		return new Promise((resolve) => setTimeout(resolve, delay));
	}
	defaultHttpHeaders() {
		return {
			"X-CSRF-Token": document.getElementsByName("csrf-token")[0].content,
			Accept: "application/json",
		};
	}
	flattenParamsRecursive(key, value, params = []) {
		if (Array.isArray(value))
			for (const v of value) this.flattenParamsRecursive(`${key}[]`, v, params);
		else if (typeof value === "object" && value !== null && value !== undefined)
			for (const [k, v] of Object.entries(value))
				this.flattenParamsRecursive(`${key}[${k}]`, v, params);
		else params.push([key, value]);

		return params;
	}
	objectToUrlSearchParams(object) {
		const params = new URLSearchParams();

		for (const [key, value] of Object.entries(object))
			for (const [k, v] of this.flattenParamsRecursive(key, value))
				params.append(k, v);

		return params;
	}
	mergeHttpOptions(urlParam, options) {
		let url = urlParam;
		if (!options.method) options.method = "GET";
		else options.method = options.method.toUpperCase();

		options.headers = Object.assign(this.defaultHttpHeaders(), options.headers);

		if (this.config.EnginePath && !url.includes(this.config.EnginePath))
			url = this.joinPath(this.config.EnginePath, url);

		if (!(options.body instanceof FormData || options.headers["Content-Type"]))
			options.headers["Content-Type"] = "application/json";

		if (options.method === "GET" && options.body) {
			url += `?${this.objectToUrlSearchParams(options.body).toString()}`;
			options.body = undefined;
		} else if (
			options.headers["Content-Type"] === "application/json" &&
			options.body &&
			typeof options.body !== "string" &&
			!(options.body instanceof String)
		)
			options.body = JSON.stringify(options.body);

		if (
			(options.method !== "GET" && options.method !== "POST") ||
			options.body instanceof FormData
		)
			options.cache = "no-cache";

		return [url, options];
	}
	httpRequest(url, options = {}, retries = 3) {
		const [mergedUrl, mergedOptions] = this.mergeHttpOptions(url, options);

		return fetch(mergedUrl, mergedOptions).then((res) => {
			if (res.ok) {
				return res.json().catch(() => undefined);
			}

			if (retries > 0)
				return this.wait(1000 * (3 / retries)).then(() =>
					this.httpRequest(mergedUrl, mergedOptions, retries - 1),
				);

			throw new Error(res.status);
		});
	}
	_prepareElement(element, innerHTML = undefined) {
		let el = element;
		if (el instanceof $) el = el[0];
		if (!el) return;

		if (innerHTML !== undefined) {
			el.dataset.dcDisableWith = el.dataset.disableWith;
			el.dataset.disableWith = innerHTML;
		} else if (el.dataset.dcDisableWith) {
			el.dataset.disableWith = el.dataset.dcDisableWith;
			el.dataset.dcDisableWith = undefined;
		}

		if (!(el.dataset.disable || el.dataset.disableWith))
			el.dataset.disable = true;

		return el;
	}
	disableElement(element, innerHTML = undefined) {
		const el = this._prepareElement(element, innerHTML);
		if (!el) return;

		Rails.disableElement(el);
		if (this.mutableNodes.includes(el.nodeName)) el.classList.add("disabled");
	}
	enableElement(element) {
		const el = this._prepareElement(element);
		if (!el) return;

		Rails.enableElement(el);
		if (this.mutableNodes.includes(el.nodeName))
			el.classList.remove("disabled");
	}
	initNewElements(selector, callback) {
		if (document.querySelector(selector))
			for (const element of document.querySelectorAll(selector))
				callback(element);
		this.htmlObserver.addCallbacks.push([selector, callback]);
	}
	_runAddCallbacks(node) {
		for (const [selector, callback] of this.htmlObserver.addCallbacks) {
			if (node.querySelector(selector))
				for (const element of node.querySelectorAll(selector))
					callback(element);
			if (node.matches(selector)) callback(node);
		}
	}
	_runRemoveCallbacks(node) {
		for (const [selector, callback] of this.htmlObserver.removeCallbacks) {
			if (node.querySelector(selector))
				for (const element of node.querySelectorAll(selector))
					callback(element);
			if (node.matches(selector)) callback(node);
		}
	}
	_addToCallbackQueue(mutations) {
		if (!this.callbackQueue.length)
			requestAnimationFrame(this._observeHtmlContent.bind(this));

		this.callbackQueue.push(mutations);
	}
	_observeHtmlContent() {
		for (const mutations of this.callbackQueue) {
			for (const mutation of mutations) {
				for (const addedNode of mutation.addedNodes)
					if (addedNode.nodeType === Node.ELEMENT_NODE)
						this._runAddCallbacks(addedNode);

				for (const removedNode of mutation.removedNodes)
					if (removedNode.nodeType === Node.ELEMENT_NODE)
						this._runRemoveCallbacks(removedNode);
			}
		}

		this.callbackQueue.length = 0;
	}
}

export default DataCycle;
