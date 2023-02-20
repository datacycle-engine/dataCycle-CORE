import domElementHelpers from '../helpers/dom_element_helpers';

class RemoteRenderer {
  constructor(selector) {
    this.selector = $(selector);
    this.intersectionObserver = new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
      rootMargin: '0px 0px 50px 0px',
      threshold: 0.1
    });
    if (DataCycle.config.remoteRenderFull) {
      this.globalObservers = [
        new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
          root: document.body
        })
      ];

      if (document.querySelector('.row.split-content.detail-content'))
        this.globalObservers.push(
          new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
            root: document.querySelector('.row.split-content.detail-content > .show-content')
          })
        );

      if (document.querySelector('.row.split-content.edit-content'))
        this.globalObservers.push(
          new IntersectionObserver(this.checkForNewVisibleElements.bind(this), {
            root: document.querySelector('.row.split-content.edit-content > .column')
          })
        );
    }

    this.init();
  }
  init() {
    this.selector.on('dc:remote:reload', '.remote-rendered', this.reload.bind(this));
    this.selector.on(
      'dc:remote:reloadOnNextOpen',
      '.remote-render, .remote-rendering, .remote-rendered',
      this.reloadOnNextOpen.bind(this)
    );
    this.selector.on(
      'click',
      '.remote-render-failed > .remote-render-error > .remote-reload-link',
      this.reloadAfterFail.bind(this)
    );

    DataCycle.initNewElements('.remote-render:not(.dc-remote-render)', this.addRemoteRenderHandler.bind(this));
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
    element.classList.add('dc-remote-render');
    this.observeElement(element);

    if (element.classList.contains('translatable-attribute')) this.addForceRenderTranslationHandler(element);
  }
  addForceRenderTranslationHandler(element) {
    $(element).on('dc:remote:forceRenderTranslations', this.forceLoadRemote.bind(this));

    if (element.classList.contains('force-render-translation'))
      $(element).triggerHandler('dc:remote:forceRenderTranslations');
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

    let remoteContainer = $(event.target).closest('.remote-render-failed');
    remoteContainer.addClass('remote-reload').removeClass('remote-render-failed');
    this.loadRemotePartial(remoteContainer);
  }
  reload(event, data) {
    event.stopPropagation();

    $(event.target).removeClass('dc-fd-initialized');
    this.loadRemotePartial(event.target, data);
  }
  reloadOnNextOpen(event, data) {
    event.stopPropagation();

    if (data) {
      let remoteOptions = $(event.target).data('remoteOptions');
      $(event.target).attr('data-remote-options', JSON.stringify(Object.assign(remoteOptions, data)));
    }

    $(event.target).addClass('remote-reload').removeClass('dc-fd-initialized');
    this.intersectionObserver.observe(event.target);
  }
  loadInitial() {
    this.selector.find('.remote-render:visible').each((_, element) => {
      if (!$(element).closest('.dropdown-pane').length) this.loadRemotePartial(element);
    });
  }
  loadRemote(target, data = undefined) {
    $(target)
      .find('.remote-render, .remote-reload')
      .addBack('.remote-render, .remote-reload')
      .filter((_, elem) => {
        return (data && data.force) || ($(elem).css('visibility') != 'hidden' && $(elem).is(':visible'));
      })
      .each((_, element) => {
        this.loadRemotePartial(element);
      });
  }
  forceLoadRemote(event) {
    event.preventDefault();
    event.stopPropagation();

    const target = event.currentTarget;

    if (target.classList.contains('remote-render')) return this.loadRemotePartial(target, null, true);
  }
  loadChangedTabs(event) {
    event.stopPropagation();
    $(event.target)
      .siblings('[data-tabs-content]')
      .find('.remote-render:visible')
      .each((_, element) => {
        this.loadRemotePartial(element);
      });
  }
  loadRemotePartial(element, additionalParams = null, forceRecursiveLoad = false) {
    let id = $(element).data('remote-render-id');

    if (id === undefined) {
      id = domElementHelpers.randomId();
      element.setAttribute('data-remote-render-id', id);
    }

    let params = {
      target: id,
      partial: $(element).data('remotePath'),
      content_for: $(element).data('remoteContentFor'),
      options: $(element).data('remoteOptions'),
      render_function: $(element).data('remoteRenderFunction'),
      render_params: $(element).data('remoteRenderParams'),
      force_recursive_load: forceRecursiveLoad
    };

    if (additionalParams) {
      for (const [key, value] of Object.entries(additionalParams)) {
        if (!params[key]) params[key] = {};
        Object.assign(params[key], value);
      }
    }

    $(element).removeClass('remote-render remote-rendered remote-reload').addClass('remote-rendering');

    return this.sendRequest(element, params);
  }
  sendRequest(element, params) {
    const promise = DataCycle.httpRequest({
      method: 'POST',
      url: '/remote_render',
      data: JSON.stringify(params),
      dataType: 'script',
      contentType: 'application/json'
    });

    promise.catch(async _error => {
      $(element)
        .html(
          `<div class="remote-render-error">${await I18n.translate(
            'frontend.remote_render.error'
          )}<a href="#" class="remote-reload-link"><i class="fa fa-repeat" aria-hidden="true"></i> ${await I18n.translate(
            'frontend.remote_render.reload'
          )}</a></div>`
        )
        .removeClass('remote-rendering')
        .addClass('remote-render-failed');
    });

    return promise;
  }
}

export default RemoteRenderer;
