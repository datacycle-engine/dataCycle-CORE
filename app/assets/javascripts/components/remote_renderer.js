import uniqueId from 'lodash/uniqueId';
import loadingIcon from '../templates/loadingIcon';

class RemoteRenderer {
  constructor(selector) {
    this.selector = $(selector);

    this.init();
  }
  init() {
    this.loadInitial();

    this.selector.on('change.zf.tabs', this.loadChangedTabs.bind(this));
    this.selector.on('dc:remote:reload', '.remote-rendered', this.reload.bind(this));
    this.selector.on(
      'dc:remote:reloadOnNextOpen',
      '.remote-render, .remote-rendering, .remote-rendered',
      this.reloadOnNextOpen.bind(this)
    );
    this.selector.on(
      'open.zf.reveal dc:remote:render dc:html:changed show.zf.dropdown dc:toggler:show down.zf.accordion',
      '*',
      this.loadRemote.bind(this)
    );
    this.selector.on(
      'click',
      '.remote-render-failed > .remote-render-error > .remote-reload-link',
      this.reloadAfterFail.bind(this)
    );
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
  }
  loadInitial() {
    this.selector.find('.remote-render:visible').each((_, element) => {
      if (!$(element).closest('.dropdown-pane').length) this.loadRemotePartial(element);
    });
  }
  loadRemote(event) {
    event.stopPropagation();

    $(event.target)
      .find('.remote-render, .remote-reload')
      .addBack('.remote-render, .remote-reload')
      .filter((_, elem) => {
        return $(elem).css('visibility') != 'hidden' && $(elem).is(':visible');
      })
      .each((_, element) => {
        this.loadRemotePartial(element);
      });
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
  loadRemotePartial(element, additionalParams = null) {
    let id = $(element).data('remote-render-id');

    if (id === undefined) {
      id = uniqueId('remote_render_');
      element.setAttribute('data-remote-render-id', id);
    }

    let params = {
      target: id,
      partial: $(element).data('remotePath'),
      content_for: $(element).data('remoteContentFor'),
      options: $(element).data('remoteOptions'),
      render_function: $(element).data('remoteRenderFunction'),
      render_params: $(element).data('remoteRenderParams')
    };

    if (additionalParams) {
      for (const [key, value] of Object.entries(additionalParams)) {
        Object.assign(params[key], value);
      }
    }

    $(element)
      .removeClass('remote-render remote-rendered remote-reload')
      .addClass('remote-rendering')
      .html(loadingIcon('show'));

    DataCycle.httpRequest({
      type: 'POST',
      url: '/remote_render',
      data: JSON.stringify(params),
      dataType: 'script',
      contentType: 'application/json'
    }).catch(async _error => {
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
  }
}

export default RemoteRenderer;
