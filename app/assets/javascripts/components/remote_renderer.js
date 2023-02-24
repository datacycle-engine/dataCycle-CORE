import DomElementHelpers from "../helpers/dom_element_helpers";

class RemoteRenderer {
	constructor() {
		this.$container = $(document);
		this.renderQueue = [];
		this.intersectionObserver = new IntersectionObserver(
			this.checkForNewVisibleElements.bind(this),
			{
				rootMargin: "0px 0px 50px 0px",
				threshold: 0.1,
			},
		);
		if (DataCycle.config.remoteRenderFull) {
			this.globalObservers = [
				new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
					root: document.body,
				}),
			];

			if (document.querySelector(".row.split-content.detail-content"))
				this.globalObservers.push(
					new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
						root: document.querySelector(
							".row.split-content.detail-content > .show-content",
						),
					}),
				);

			if (document.querySelector(".row.split-content.edit-content"))
				this.globalObservers.push(
					new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
						root: document.querySelector(
							".row.split-content.edit-content > .column",
						),
					}),
				);
		}

		this.init();
	}
	init() {
		this.$container.on(
			"dc:remote:reload",
			".remote-rendered",
			this.reload.bind(this),
		);
		this.$container.on(
			"dc:remote:reloadOnNextOpen",
			".remote-render, .remote-rendering, .remote-rendered",
			this.reloadOnNextOpen.bind(this),
		);
		this.$container.on(
			"click",
			".remote-render-failed > .remote-render-error > .remote-reload-link",
			this.reloadAfterFail.bind(this),
		);

		DataCycle.initNewElements(
			".remote-render:not(.dc-remote-render)",
			this.addRemoteRenderHandler.bind(this),
		);
	}
	observeElement(element) {
		this.intersectionObserver.observe(element);

		if (!DataCycle.config.remoteRenderFull) return;

		for (const observer of this.globalObservers) observer.observe(element);
	}
	unobserveElement(element) {
		this.intersectionObserver.unobserve(element);

		if (!DataCycle.config.remoteRenderFull) return;

		for (const observer of this.globalObservers) observer.unobserve(element);
	}
	addRemoteRenderHandler(element) {
		element.classList.add("dc-remote-render");
		this.observeElement(element);

		if (element.classList.contains("translatable-attribute"))
			this.addForceRenderTranslationHandler(element);
	}
	addForceRenderTranslationHandler(element) {
		$(element).on(
			"dc:remote:forceRenderTranslations",
			this.forceLoadRemote.bind(this),
		);

		if (element.classList.contains("force-render-translation"))
			$(element).triggerHandler("dc:remote:forceRenderTranslations");
	}
	checkForNewVisibleElements(entries) {
		for (const entry of entries) {
			if (!entry.isIntersecting) continue;

			this.unobserveElement(entry.target);
			this.loadRemote(entry.target);
		}
	}
	reloadAfterFail(event) {
		event.preventDefault();
		event.stopPropagation();

		let remoteContainer = event.target.closest(".remote-render-failed");
		remoteContainer.classList.add("remote-reload");
		remoteContainer.classList.remove("remote-render-failed");

		this.loadRemotePartial(remoteContainer);
	}
	reload(event, data) {
		event.stopPropagation();

		event.target.classList.remove("dc-fd-initialized");
		this.loadRemotePartial(event.target, data);
	}
	reloadOnNextOpen(event, data) {
		event.stopPropagation();

		if (data) {
			let remoteOptions = DomElementHelpers.parseDataAttribute(
				event.target.dataset.remoteOptions,
			);
			event.target.dataset.remoteOptions = JSON.stringify(
				Object.assign({}, remoteOptions, data),
			);
		}

		event.target.classList.add("remote-reload");
		event.target.classList.remove("dc-fd-initialized");
		this.intersectionObserver.observe(event.target);
	}
	loadRemote(target, data = undefined) {
		if (
			target.matches(".remote-render, .remote-reload") &&
			(data?.force || DomElementHelpers.isVisible(target))
		)
			this.loadRemotePartial(target);
		if (target.querySelector(".remote-render, .remote-reload"))
			for (const elem of target.querySelectorAll(
				".remote-render, .remote-reload",
			))
				if (DomElementHelpers.isVisible(elem)) this.loadRemotePartial(elem);
	}
	forceLoadRemote(event) {
		event.preventDefault();
		event.stopPropagation();

		const target = event.currentTarget;

		if (target.classList.contains("remote-render"))
			return this.loadRemotePartial(target, null, true);
	}
	loadRemotePartial(
		element,
		additionalParams = null,
		forceRecursiveLoad = false,
	) {
		const params = {
			partial: element.dataset.remotePath,
			render_function: element.dataset.remoteRenderFunction,
			force_recursive_load: forceRecursiveLoad,
			options:
				DomElementHelpers.parseDataAttribute(element.dataset.remoteOptions) ||
				{},
			render_params:
				DomElementHelpers.parseDataAttribute(
					element.dataset.remoteRenderParams,
				) || {},
		};

		if (additionalParams?.options)
			Object.assign(params.options, additionalParams.options);
		if (additionalParams?.render_params)
			Object.assign(params.render_params, additionalParams.render_params);

		element.classList.add("remote-rendering");
		element.classList.remove(
			"remote-render",
			"remote-rendered",
			"remote-reload",
		);

		return this.sendRequest(element, params);
	}
	async renderError(element) {
		element.innerHTML = `<div class="remote-render-error">${await I18n.translate(
			"frontend.remote_render.error",
		)}<a href="#" class="remote-reload-link"><i class="fa fa-repeat" aria-hidden="true"></i> ${await I18n.translate(
			"frontend.remote_render.reload",
		)}</a></div>`;

		element.classList.add("remote-render-failed");
		element.classList.remove("remote-rendering");
	}
	renderNewHtml() {
		for (const [target, html] of this.renderQueue) {
			target.innerHTML = html;
			target.classList.add("remote-rendered");
			target.classList.remove("remote-rendering");
		}

		this.renderQueue.length = 0;
	}
	addToRenderQueue(element, data) {
		if (!this.renderQueue.length)
			requestAnimationFrame(this.renderNewHtml.bind(this));

		this.renderQueue.push([element, data?.html]);
	}
	sendRequest(element, data) {
		const promise = DataCycle.httpRequest({
			method: "POST",
			url: "/remote_render",
			data: JSON.stringify(data),
			contentType: "application/json",
		});

		promise
			.then(this.addToRenderQueue.bind(this, element))
			.catch(this.renderError.bind(this, element));

		return promise;
	}
}

export default RemoteRenderer;
