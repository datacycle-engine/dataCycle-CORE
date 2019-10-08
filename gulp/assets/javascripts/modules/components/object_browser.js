var ConfirmationModal = require('./../components/confirmation_modal');
var Sortable = require('sortablejs');

// Object Browser Module
class ObjectBrowser {
  constructor(selector) {
    this.element = selector;
    this.id = selector.prop('id');
    this.scrollTop = 0;
    this.overlay = $('#object_browser_' + this.id);
    this.label = $('[for=' + this.id + ']').text();
    this.overlay_per = 25;
    this.per = selector.data('per') || 5;
    this.type = selector.data('type');
    this.locale = selector.data('locale');
    this.key = selector.data('key');
    this.hidden_field_id = selector.data('hidden-field-id');
    this.object_id = selector.data('object-id');
    this.object_key = selector.data('object-key');
    this.definition = selector.data('definition');
    this.options = selector.data('options');
    this.class = selector.data('class');
    this.table = selector.data('table');
    this.max = selector.data('max');
    this.min = selector.data('min');
    this.limitedBy = selector.data('limited-by');
    this.index = this.per;
    this.editable = selector.data('editable');
    this.page = 1;
    this.loading = false;
    this.search = '';
    this.url = window.DATA_CYCLE_ENGINE_PATH + '/object_browser';
    this.total = 0;
    this.ids = selector.data('objects') || [];
    this.chosen = this.ids.slice(0);
    this.selected = '';
    this.excluded = [];
    this.sortable;
    this.content_id = this.element.data('content-id');
    this.content_type = this.element.data('content-type');
    this.prefix = selector.data('prefix');
    this.requests = [];
    this.setup();
  }
  setup() {
    var self = this;
    this.sortable = new Sortable(this.element.find('> .media-thumbs > .object-thumbs').get(0), {
      handle: '.draggable-handle',
      draggable: 'li.item'
    });
    this.ids = this.ids.diff(
      $.map(this.element.find('> .media-thumbs > .object-thumbs > li.item'), (val, i) => $(val).data('id'))
    );
    // initialize all eventhandlers
    this.overlay.on('open.zf.reveal', this.openOverlay.bind(this));
    this.overlay.on('closed.zf.reveal', this.closeOverlay.bind(this));
    this.overlay.children('.items').on(
      'scroll',
      function(event) {
        var elem = $(event.currentTarget);
        if (
          elem[0].scrollHeight - elem.scrollTop() - 200 <= elem.outerHeight() &&
          !this.loading &&
          this.overlay.children('.items').children('li.item').length < this.total
        ) {
          this.page += 1;
          this.loadObjects();
        }
      }.bind(this)
    );
    this.overlay.find('.object-browser-search').on('change', function(event) {
      event.preventDefault();
      self.search = $(this).val();
      self.page = 1;
      self.loadObjects(false);
    });
    this.overlay.find('.chosen-items-container').on('click', 'li.item', function(event) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (self.selected != $(this).data('id')) {
        self.loadDetails($(this).data('id'));
      }
    });
    this.overlay.children('.items').on('click', 'li.item', function(event) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (self.selected != $(this).data('id')) {
        $(this).addClass('in-object-browser');
        self.loadDetails($(this).data('id'));
      }
      if (self.chosen.indexOf($(this).data('id')) == -1) {
        self.addObject($(this).data('id'), $(this).clone(), event);
      } else {
        self.removeObject($(this).data('id'), event);
      }
    });
    this.element.on('click', '.delete-thumbnail', event => {
      event.preventDefault();
      event.stopPropagation();
      if (this.validate('-', this.chosen.length - 1)) {
        this.removeThumbObject(event.target);
      }
    });
    this.overlay.find('.chosen-items-container').on('click', '.delete-thumbnail', function(event) {
      event.preventDefault();
      event.stopPropagation();
      self.removeObject(
        $(this)
          .closest('li.item')
          .data('id'),
        event
      );
    });
    this.overlay.find('.buttons .save-object-browser').on('click', event => {
      event.preventDefault();
      if (this.validate()) {
        this.setChosen();
        this.overlay.foundation('close');
        this.element.closest('.form-element').trigger('change');
      }
    });
    this.element.on('dc:update:chosen', (event, data) => {
      this.chosen = this.chosen.concat(data.chosen.diff(this.chosen));
      $($.map(data.chosen, id => this.element.children('input:hidden[value="' + id + '"]'))).each((index, elem) =>
        $(elem).remove()
      );
      this.updateChosenCounter();
      this.overlay.find('.items li.item .reveal.media-preview').each(function() {
        if (
          $(this)
            .prop('id')
            .indexOf('overlay_') == -1
        )
          $(this).prop('id', 'overlay_' + $(this).prop('id'));
      });
      this.element.find('.object-thumbs li.item .reveal.media-preview').each((index, element) => {
        $(element).foundation();
      });
    });
    this.element.on('dc:import:data', (event, data) => {
      let new_items = [];
      if (data.external_ids != undefined) new_items = data.external_ids;
      else if (data.value != undefined)
        new_items = data.value.diff(
          $.map(this.element.find('> .media-thumbs > .object-thumbs > li.item'), (val, i) => $(val).data('id'))
        );
      if (new_items.length > 0 && this.validate('+', this.chosen.length + new_items.length)) {
        this.findObjects(new_items, data.external_ids != undefined);
      }
    });
    this.overlay.on('dc:import:complete', (event, data) => {
      if (this.excluded.indexOf(data.id) === -1) this.excluded.push(data.id);
      this.overlay
        .children('.items')
        .find('[data-id=' + data.id + ']')
        .get(0)
        .scrollIntoView({
          behavior: 'smooth'
        });
      this.addObject(data.id, this.overlay.find('[data-id=' + data.id + ']').clone(), event);
      $('#new_' + this.id + '.in-object-browser form').trigger('reset');
    });
    $(document).on(
      'dc:html:changed',
      '#new_' + this.id + '.in-object-browser .new-content-form',
      this.initNewFormHandlers.bind(this)
    );
    this.element.on('dc:locale:changed', this.updateLocale.bind(this));
    this.element.closest('form').on('reset', this.reset.bind(this));

    if (this.limitedBy === Object(this.limitedBy)) {
      let filterItem = this.element;
      this.limitedBy.forEach(item => {
        filterItem = filterItem[item[0]](item[1]);
      });
      this.limitedBy = filterItem;

      this.removeDeletedItem();
      this.limitedBy.on('change', this.removeDeletedItem.bind(this));
    } else this.limitedBy = undefined;
  }
  updateLocale(e) {
    e.stopPropagation();
    this.locale = this.element.data('locale');
  }
  initNewFormHandlers(e) {
    $('#new_' + this.id + '.in-object-browser form')
      .off('submit_without_redirect')
      .on('submit_without_redirect', event => {
        event.preventDefault();
        event.stopImmediatePropagation();
        var form_data = $(event.target).serializeJSON();
        $.extend(form_data, {
          type: this.type,
          locale: this.locale,
          overlay_id: '#object_browser_' + this.id,
          key: this.key,
          definition: this.definition,
          editable: this.editable,
          options: this.options,
          content_id: this.content_id,
          class: this.class,
          prefix: this.prefix,
          objects: this.chosen,
          new_overlay_id: '#new_' + this.id
        });
        $.ajax({
          url: $(event.target).prop('action'),
          method: 'POST',
          data: JSON.stringify(form_data),
          dataType: 'script',
          contentType: 'application/json'
        });
      });
  }
  removeThumbObject(element) {
    let item = $(element).closest('li.item');
    let elem_id = item.data('id');
    this.chosen = this.chosen.diff(elem_id);
    this.ids = this.ids.diff(elem_id);
    this.element.children('input:hidden[value="' + elem_id + '"]').remove();
    $('.reveal-overlay > #media_reveal_' + elem_id)
      .parent('.reveal-overlay')
      .remove();
    item.remove();
    if (this.chosen.length == 0) this.renderHiddenField();
    this.element.closest('.form-element').trigger('change');
  }
  renderHiddenField() {
    this.element
      .find('> .media-thumbs > .object-thumbs')
      .html('<input type="hidden" id="' + this.hidden_field_id + '" name="' + this.key + '[]">');
  }
  findObjects(ids, external) {
    $.ajax({
      url: this.url + '/find',
      method: 'POST',
      dataType: 'script',
      data: JSON.stringify({
        type: this.type,
        locale: this.locale,
        key: this.key,
        prefix: this.prefix,
        definition: this.definition,
        options: this.options,
        ids: ids,
        editable: this.editable,
        class: this.class,
        content_id: this.content_id,
        content_type: this.content_type,
        objects: this.chosen,
        external: external
      }),
      contentType: 'application/json'
    });
  }
  validate(type = '~', new_length = this.chosen.length) {
    if (type != '-' && this.max != 0 && new_length > this.max) {
      new ConfirmationModal({ text: 'Maximalanzahl: ' + this.max });
      return false;
    } else if (type != '+' && this.min != 0 && new_length < this.min) {
      new ConfirmationModal({ text: 'Mindestanzahl: ' + this.min });
      return false;
    }
    return true;
  }
  setChosen() {
    if (this.chosen.length == 0) this.renderHiddenField();
    else {
      this.element
        .children('.media-thumbs')
        .children('.object-thumbs')
        .html(this.overlay.find('.chosen-items-container li.item').clone())
        .children('li.item')
        .find('.reveal.media-preview')
        .each(function() {
          if (
            $(this)
              .prop('id')
              .indexOf('overlay_') != -1
          )
            $(this).prop(
              'id',
              $(this)
                .prop('id')
                .replace('overlay_', '')
            );
          $(this).foundation();
        });
      this.element
        .children('.media-thumbs')
        .children('.object-thumbs')
        .children('li.item')
        .find('[data-tooltip]')
        .each(function() {
          $(this)
            .attr('title', $(this).data('title'))
            .foundation();
        });
    }
  }
  addObject(id, element, event) {
    if (this.chosen.indexOf(id) === -1) {
      this.chosen.push(id);
      this.overlay.find('.chosen-items-container').append(element);
      $(element)
        .find('[data-tooltip]')
        .each(function() {
          $(this)
            .attr('title', $(this).data('title'))
            .foundation();
        });
      this.overlay
        .children('.items')
        .find('li.item[data-id=' + id + ']')
        .addClass('active');
      this.updateChosenCounter();
    }
  }
  removeObject(id, event) {
    this.chosen = this.chosen.diff(id);
    this.element.children('input:hidden[value="' + id + '"]').remove();
    this.overlay.find('.chosen-items-container [data-id=' + id + ']').remove();
    this.overlay
      .children('.items')
      .find('li.item[data-id=' + id + ']')
      .removeClass('active');
    this.updateChosenCounter();
  }
  updateChosenCounter() {
    var html = '';
    if (this.chosen.length > 1) html = '<strong>' + this.chosen.length + '</strong> Elemente auswählen';
    else if (this.chosen.length == 1) html = '<strong>' + this.chosen.length + '</strong> Element auswählen';
    else html = 'Keine Elemente auswählen';
    this.overlay.find('.chosen-counter').html(html);
  }
  loadMore(loaded_ids) {
    $.ajax({
      url: window.DATA_CYCLE_ENGINE_PATH + '/' + this.content_type + '/' + this.content_id + '/load_more_linked_objects',
      method: 'GET',
      dataType: 'script',
      data: {
        key: this.object_key,
        complete_key: this.key,
        locale: this.locale,
        definition: this.definition,
        options: this.options,
        class: this.class,
        editable: this.editable,
        content_id: this.content_id,
        content_type: this.content_type,
        load_more_action: 'object_browser',
        load_more_type: 'all',
        load_more_except: loaded_ids
      },
      contentType: 'application/json'
    }).done(() => {
      this.chosen = this.chosen.concat(this.ids.diff(this.chosen));
      this.updateChosenCounter();
      this.ids = [];
      this.loadObjects(false);
    });
  }
  loadDetails(id) {
    this.selected = id;
    $.ajax({
      url: this.url + '/details',
      method: 'POST',
      dataType: 'script',
      data: JSON.stringify({
        type: this.type,
        locale: this.locale,
        key: this.key,
        prefix: this.prefix,
        definition: this.definition,
        options: this.options,
        class: this.class,
        id: id
      }),
      contentType: 'application/json'
    });
  }
  resetOverlay() {
    this.overlay.find('.object-browser-search').val('');
    this.overlay.find('.chosen-items-container li.item').remove();
    this.chosen = [];
    this.search = '';
    this.excluded = [];
    this.page = 1;
  }
  reset(event) {
    this.element.find('.media-thumbs li.item').each((_, element) => {
      this.removeThumbObject(element);
    });
  }
  setPreselected() {
    this.overlay
      .find('.chosen-items-container')
      .html(this.element.find('> .media-thumbs > .object-thumbs > li.item').clone())
      .find('[data-tooltip]')
      .each(function() {
        $(this)
          .attr('title', $(this).data('title'))
          .foundation();
      });
    this.chosen = $.map(this.element.find('> .media-thumbs > .object-thumbs > li.item'), (val, i) => $(val).data('id'));
  }
  openOverlay(ev) {
    if ($('.reveal:visible').not(this.overlay).length) this.overlay.addClass('full-height');
    this.resetOverlay();
    this.setPreselected();
    this.updateChosenCounter();
    // set breadcrumb link + text
    var text = $('.breadcrumb ul li:last-child').html();
    $('.breadcrumb ul li:last-child').html(
      '<a class="close-object-browser" href="#">' +
        text +
        '</a><i class="fa fa-angle-right breadcrumb-separator" aria-hidden="true"></i>'
    );
    $('.breadcrumb ul').append(
      '<li><span class="breadcrumb-text"><i><i class="fa fa-files-o" aria-hidden="true"></i>' +
        this.label +
        ' auswählen</i></span></li>'
    );
    $('.breadcrumb ul li').on('click', '.close-object-browser', event => {
      event.preventDefault();
      this.overlay.foundation('close');
    });
    $(window).on('message.object_browser onmessage.object_browser', this.import.bind(this));
    let loaded = $.map(this.element.find('> .media-thumbs > .object-thumbs > li.item'), (val, i) => $(val).data('id'));
    if (this.ids.diff(loaded).length > 0) this.loadMore(loaded);
    else this.loadObjects(false);
  }
  closeOverlay(ev) {
    this.overlay.removeClass('full-height');
    $('.breadcrumb ul li:last-child').remove();
    var text = $('.breadcrumb ul li:last-child a.close-object-browser').html();
    $('.breadcrumb ul li:last-child').html(text);
    $('.breadcrumb ul li').off('click');
    $(window).off('message.object_browser onmessage.object_browser');
    $('#asset-upload-reveal-default').off('closed.zf.reveal');
  }
  // import media from media_archive reveal
  import(event) {
    if (event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'import') {
      var AUTH_TOKEN = $('meta[name=csrf-token]').attr('content');
      $.ajax({
        type: 'POST',
        url: window.DATA_CYCLE_ENGINE_PATH + '/things/import',
        dataType: 'script',
        data: JSON.stringify({
          authenticity_token: AUTH_TOKEN,
          type: this.type + '_object',
          data: event.originalEvent.data.data,
          locale: this.locale,
          key: this.key,
          prefix: this.prefix,
          editable: this.editable,
          definition: this.definition,
          options: this.options,
          editable: this.editable,
          objects: this.chosen
        }),
        contentType: 'application/json'
      })
        .done(
          function(data) {
            this.overlay.find('.items li.item .reveal.media-preview').each(function() {
              if (
                $(this)
                  .prop('id')
                  .indexOf('overlay_') == -1
              )
                $(this).prop('id', 'overlay_' + $(this).prop('id'));
            });
          }.bind(this)
        )
        .always(() => {
          $('#new_' + this.id).foundation('close');
        });
    }
  }
  loadObjects(append = true) {
    if (!append) {
      this.excluded = [];
      this.overlay.children('.items').scrollTop(0);
      this.overlay
        .children('.items')
        .html('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
    }
    this.overlay.find('.items .loading').show();
    this.loading = true;
    this.requests.forEach(request => {
      request.abort();
      this.requests = this.requests.filter(r => r != request);
    });
    this.requests.push(
      $.ajax({
        url: this.url + '/show',
        method: 'POST',
        dataType: 'script',
        data: JSON.stringify({
          page: this.page,
          per: this.overlay_per,
          type: this.type,
          locale: this.locale,
          key: this.key,
          definition: this.definition,
          options: this.options,
          search: this.search,
          objects: this.chosen,
          editable: this.editable,
          excluded: this.excluded,
          content_id: this.content_id,
          content_type: this.content_type,
          prefix: this.prefix,
          filter_ids: this.filteredIds(),
          append: append
        }),
        contentType: 'application/json'
      })
        .done(data => {
          this.total = this.overlay.data('total');
          this.overlay.find('.items li.item .reveal.media-preview').each(function() {
            if (
              $(this)
                .prop('id')
                .indexOf('overlay_') == -1
            )
              $(this).prop('id', 'overlay_' + $(this).prop('id'));
          });
          this.loading = false;
          if (
            this.overlay.children('.items').children('li.item').length < this.total &&
            this.overlay
              .children('.items')
              .children('li.item')
              .last()
              .offset().top -
              this.overlay.children('.items').offset().top <
              this.overlay
                .children('.items')
                .first()
                .outerHeight()
          ) {
            this.page += 1;
            this.loadObjects();
          }
        })
        .always((data, text, jqXHR) => {
          this.requests = this.requests.filter(r => r != jqXHR);
        })
    );
  }
  removeDeletedItem() {
    if (!this.chosen.length) return;

    let toRemove = this.chosen.diff(this.filteredIds());
    if (toRemove.length) {
      toRemove.forEach(item => {
        this.removeThumbObject(this.element.find('> .media-thumbs > .object-thumbs > li.item[data-id="' + item + '"]'));
      });
    }
  }
  filteredIds() {
    if (this.limitedBy === undefined) return [];

    return this.limitedBy
      .find('> .object-browser input:hidden')
      .map((_, item) => $(item).val())
      .get();
  }
}

module.exports = ObjectBrowser;
