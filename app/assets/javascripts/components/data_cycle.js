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

			if (parts.length > 0) segment = segment.replace(/^\//, "");

			segment = segment.replace(/\/$/, "");

			return parts.concat(segment.split("/"));
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
	mergeHttpOptions(url, options) {
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
		[url, options] = this.mergeHttpOptions(url, options);

		return fetch(url, options).then((res) => {
			if (res.ok) {
				return res.json().catch(() => undefined);
			}

			if (retries > 0)
				return this.wait(1000 * (3 / retries)).then(() =>
					this.httpRequest(url, options, retries - 1),
				);

			throw new Error(res.status);
		});
	}
	_prepareElement(element, innerHTML = undefined) {
		if (element instanceof $) element = element[0];
		if (!element) return;

		if (innerHTML !== undefined) {
			element.dataset.dcDisableWith = element.dataset.disableWith;
			element.dataset.disableWith = innerHTML;
		} else if (element.dataset.dcDisableWith) {
			element.dataset.disableWith = element.dataset.dcDisableWith;
			element.dataset.dcDisableWith = undefined;
		}

		if (!(element.dataset.disable || element.dataset.disableWith))
			element.dataset.disable = true;

		return element;
	}
	disableElement(element, innerHTML = undefined) {
		element = this._prepareElement(element, innerHTML);
		if (!element) return;

		Rails.disableElement(element);
		if (this.mutableNodes.includes(element.nodeName))
			element.classList.add("disabled");
	}
	enableElement(element) {
		element = this._prepareElement(element);
		if (!element) return;

		Rails.enableElement(element);
		if (this.mutableNodes.includes(element.nodeName))
			element.classList.remove("disabled");
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
