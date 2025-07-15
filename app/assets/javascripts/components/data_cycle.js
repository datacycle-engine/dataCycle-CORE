import { nanoid } from "nanoid";
import { showToast } from "../components/toast_notification";
import ObserverHelpers from "../helpers/observer_helpers";
import DataCycleHttpClient from "./data_cycle_http_client";

class DataCycle {
	constructor(config = {}) {
		// biome-ignore lint/correctness/noConstructorReturn: <explanation>
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
					'> input[type="checkbox"]',
					'> input[type="radio "]',
					'> input[type="number"]',
					'> .duration-slider > div > input[type="number"]',
				],
				retryableHttpCodes: [401, 403, 408, 500, 501, 502, 503, 504, 507, 509],
				remoteRenderFull: false,
			},
			config,
		);

		this.uiLocale = document.documentElement.lang;
		this.globalPromises = {};
		this.globals = {};
		this.windowId = nanoid();
		this.showToast = showToast;

		this.htmlObserver = {
			observer: new MutationObserver(this._addToCallbackQueue.bind(this)),
			intersection: new IntersectionObserver(
				this._lazyInitElement.bind(this),
				ObserverHelpers.intersectionObserverConfig,
			),
			addCallbacks: {},
			removeCallbacks: {},
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
	_prepareElement(element, innerHTML = undefined) {
		let el = element;
		if (el instanceof $) el = el[0];
		if (!el) return;

		if (innerHTML !== undefined) {
			el.dataset.dcDisableWith = el.dataset.disableWith ?? "";
			el.dataset.disableWith = innerHTML;
		} else if (el.hasAttribute("data-dc-disable-with")) {
			if (!el.dataset.dcDisableWith) {
				delete el.dataset.disableWith;
			} else {
				el.dataset.disableWith = el.dataset.dcDisableWith;
			}
			delete el.dataset.dcDisableWith;
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
	registerAddCallback(selector, identifier, callback, lazy = false) {
		const [identifierFull, selectorKey] = this._generateSelector(
			selector,
			identifier,
		);

		if (!Object.hasOwn(this.htmlObserver.addCallbacks, selectorKey)) {
			this.htmlObserver.addCallbacks[selectorKey] = {
				lazy,
				callback,
				identifier: identifierFull,
			};
		}
		if (document.querySelector(selectorKey))
			for (const element of document.querySelectorAll(selectorKey))
				this._runCallback(element, selectorKey);
	}
	registerLazyAddCallback(selector, identifier, callback) {
		this.registerAddCallback(selector, identifier, callback, true);
	}
	registerRemoveCallback(selector, callback) {
		if (!Object.hasOwn(this.htmlObserver.removeCallbacks, selector)) {
			this.htmlObserver.removeCallbacks[selector] = callback;
		}
	}
	_generateSelector(selector, identifier) {
		const identifierFull =
			identifier.startsWith("dcjs-") || identifier.startsWith("dc-")
				? identifier
				: `dcjs-${identifier}`;

		return [
			identifierFull,
			selector
				.split(",")
				.map((v) => `${v.trim()}:not(.${identifierFull})`)
				.join(", "),
		];
	}
	_lazyInitElement(entries, observer) {
		for (const entry of entries) {
			if (!entry.isIntersecting) continue;

			const item = entry.target;
			observer.unobserve(item);
			const { callback } = this.htmlObserver.addCallbacks[item.dcSelectorKey];
			this._runImmediateCallback(item, callback);
		}
	}
	_runImmediateCallback(element, callback) {
		if (!element || !callback) return;

		callback(element);
	}
	_runLazyCallback(element, selectorKey) {
		if (!element || !selectorKey) return;

		element.dcSelectorKey = selectorKey;
		this.htmlObserver.intersection.observe(element);
	}
	_runCallback(element, selectorKey) {
		const { identifier, callback, lazy } =
			this.htmlObserver.addCallbacks[selectorKey];

		element.classList.add(identifier);

		if (lazy) this._runLazyCallback(element, selectorKey);
		else this._runImmediateCallback(element, callback);
	}
	_runAddCallbacks(node) {
		for (const selectorKey of Object.keys(this.htmlObserver.addCallbacks)) {
			if (node.querySelector(selectorKey))
				for (const element of node.querySelectorAll(selectorKey))
					this._runCallback(element, selectorKey);
			if (node.matches(selectorKey)) this._runCallback(node, selectorKey);
		}
	}
	_runRemoveCallback(element, selector) {
		if (!element || !selector) return;

		const callback = this.htmlObserver.removeCallbacks[selector];

		if (callback) callback(element);
	}
	_runRemoveCallbacks(node) {
		for (const selectorKey of Object.keys(this.htmlObserver.removeCallbacks)) {
			if (node.querySelector(selectorKey))
				for (const element of node.querySelectorAll(selectorKey))
					this._runRemoveCallback(element, selectorKey);
			if (node.matches(selectorKey)) this._runRemoveCallback(node, selectorKey);
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

Object.assign(DataCycle.prototype, DataCycleHttpClient);

export default DataCycle;
