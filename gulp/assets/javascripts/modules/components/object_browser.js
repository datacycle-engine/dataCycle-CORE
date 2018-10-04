var ConfirmationModal = require('./../components/confirmation_modal');
var Sortable = require('sortablejs');

// Object Browser Module
var ObjectBrowser = function (selector) {
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
  this.object_id = selector.data('object-id');
  this.object_key = selector.data('object-key');
  this.definition = selector.data('definition');
  this.options = selector.data('options');
  this.class = selector.data('class');
  this.table = selector.data('table');
  this.max = selector.data('max');
  this.min = selector.data('min');
  this.index = this.per;
  this.editable = selector.data('editable');
  this.page = 1;
  this.loading = false;
  this.search = "";
  this.url = "/object_browser";
  this.total = 0;
  this.ids = selector.data('objects') || [];
  this.chosen = this.ids.slice(0);
  this.selected = '';
  this.excluded = [];
  this.sortable;
  this.content_id = this.element.data('content-id');
  this.content_type = this.element.data('content-type');

  this.setup();
};

ObjectBrowser.prototype.setup = function () {
  var self = this;

  this.sortable = new Sortable(this.element.find('> .media-thumbs > .object-thumbs')[0], {
    handle: '.draggable-handle',
    draggable: '.item'
  });

  this.ids = this.ids.diff($.map(this.element.find('> .media-thumbs > .object-thumbs > .item'), (val, i) => $(val).data('id')));

  // initialize all eventhandlers
  this.overlay.on('open.zf.reveal', this.openOverlay.bind(this));
  this.overlay.on('closed.zf.reveal', this.closeOverlay.bind(this));

  this.overlay.children(".items").on("scroll", function (event) {
    var elem = $(event.currentTarget);

    if (elem[0].scrollHeight - elem.scrollTop() - 200 <= elem.outerHeight() && !this.loading && this.overlay.children('.items').children('.item').length < this.total) {
      this.page += 1;
      this.loadObjects();
    }
  }.bind(this));

  this.overlay.find('.object-browser-search').on('change', function (event) {
    event.preventDefault();
    self.search = $(this).val();
    self.page = 1;
    self.loadObjects(false);
  });

  this.overlay.find('.chosen-items-container').on('click', '.item', function (event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    if (self.selected != $(this).data('id')) {
      self.loadDetails($(this).data('id'));
    }
  });

  this.overlay.children(".items").on('click', '.item', function (event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    if (self.selected != $(this).data('id')) {
      $(this).addClass('in-object-browser');
      self.loadDetails($(this).data('id'));
    }
    if (self.chosen.indexOf($(this).data('id')) == -1) {
      self.addObject($(this).data('id'), $(this).clone(true), event);
    } else {
      self.removeObject($(this).data('id'), event);
    }
  });

  this.element.on('click', '.delete-thumbnail', function (event) {
    event.preventDefault();
    event.stopPropagation();
    if (self.min != 0 && self.chosen.length <= self.min) {
      var confirmationModal = new ConfirmationModal("Mindestanzahl: " + self.min);
    } else {
      self.chosen = self.chosen.diff($(this).parent().data('id'));
      self.ids = self.ids.diff($(this).parent().data('id'));
      self.element.children('input:hidden[value="' + $(this).parent().data('id') + '"]').remove();
      $('.reveal-overlay > #media_reveal_' + $(this).parent().data('id')).parent('.reveal-overlay').remove();
      $(this).parent().remove();
      if (self.chosen.length == 0) self.renderHiddenField();
    }
  });

  this.overlay.find('.chosen-items-container').on('click', '.delete-thumbnail', function (event) {
    event.preventDefault();
    event.stopPropagation();
    self.removeObject($(this).parent().data('id'), event);
  });

  this.overlay.find('.buttons .save-object-browser').on('click', function (event) {
    event.preventDefault();
    this.setChosen();
    this.overlay.foundation("close");
  }.bind(this));

  this.element.on('update-chosen', (event, data) => {
    this.chosen = this.chosen.concat(data.chosen.diff(this.chosen));

    $($.map(data.chosen, id => this.element.children('input:hidden[value="' + id + '"]'))).each((index, elem) => $(elem).remove());

    this.updateChosenCounter();
    this.overlay.find('.items .item .reveal.media-preview').each(function () {
      if ($(this).prop('id').indexOf('overlay_') == -1) $(this).prop('id', 'overlay_' + $(this).prop('id'));
    });

    this.element.find('.object-thumbs .item .reveal.media-preview').each((index, element) => {
      $(element).foundation();
    });
  });

  this.element.on('import-data', (event, data) => {
    let new_items = [];
    if (data.external_ids != undefined) new_items = data.external_ids;
    else if (data.ids != undefined) new_items = data.ids.diff($.map(this.element.find('> .media-thumbs > .object-thumbs > .item'), (val, i) => $(val).data('id')));

    if (new_items.length > 0 && ((this.chosen.length + new_items.length) <= this.max || this.max == 0)) {
      this.findObjects(new_items, (data.external_ids != undefined));
    } else if (this.max != 0 && (this.chosen.length + new_items.length) > this.max) {
      var confirmationModal = new ConfirmationModal("Maximalanzahl: " + self.max);
    }
  });

  this.overlay.on('import-complete', function (event, data) {
    if (this.excluded.indexOf(data.id) === -1) this.excluded.push(data.id);

    this.overlay.children('.items').find('[data-id=' + data.id + ']').get(0).scrollIntoView({
      behavior: "smooth"
    });
    this.addObject(data.id, this.overlay.find('[data-id=' + data.id + ']').clone(true), event);
  }.bind(this));

  $('#new_' + this.id).addClass('in-object-browser');

  $('#new_' + this.id).on('open.zf.reveal', function (event) {
    $(this).find('form').on('submit_without_redirect', function (ev, data) {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      var form_data = $(this).serializeJSON();
      $.extend(form_data, {
        type: self.type,
        locale: self.locale,
        overlay_id: '#object_browser_' + self.id,
        key: self.key,
        definition: self.definition,
        editable: self.editable,
        options: self.options,
        class: self.class,
        objects: self.chosen,
        new_overlay_id: '#new_' + self.id,
        source: 'object_browser'
      });

      $.ajax({
        url: $(this).prop('action'),
        method: 'POST',
        data: JSON.stringify(form_data),
        dataType: 'script',
        contentType: 'application/json'
      });
    });
  });
};

ObjectBrowser.prototype.renderHiddenField = function () {
  this.element.find('> .media-thumbs > .object-thumbs').html('<input type="hidden" id="' + this.key.replace(/\[/g, '_').replace(/\]/g, '') + '_default" name="' + this.key + '[]">');
};

ObjectBrowser.prototype.findObjects = function (ids, external) {
  $.ajax({
    url: this.url + '/find',
    method: 'POST',
    dataType: 'script',
    data: JSON.stringify({
      type: this.type,
      locale: this.locale,
      key: this.key,
      definition: this.definition,
      options: this.options,
      ids: ids,
      editable: this.editable,
      class: this.class,
      objects: this.chosen,
      external: external
    }),
    contentType: 'application/json'
  });
};

ObjectBrowser.prototype.setChosen = function () {
  if (this.chosen.length == 0) this.renderHiddenField();
  else {
    this.element.children('.media-thumbs').children('.object-thumbs').html(this.overlay.find('.chosen-items-container .item').clone()).children('.item').find('.reveal.media-preview').each(function () {
      if ($(this).prop('id').indexOf('overlay_') != -1) $(this).prop('id', $(this).prop('id').replace('overlay_', ''));
      $(this).foundation();
    });
  }
};

ObjectBrowser.prototype.addObject = function (id, element, event) {
  if (this.max != 0 && this.chosen.length >= this.max) {
    var confirmationModal = new ConfirmationModal("Maximalanzahl: " + this.max);
  } else {
    if (this.chosen.indexOf(id) === -1) {
      this.chosen.push(id);
      this.overlay.find('.chosen-items-container').append(element);
      this.overlay.children(".items").find('.item[data-id=' + id + ']').addClass('active');
      this.updateChosenCounter();
    }
  }
};

ObjectBrowser.prototype.removeObject = function (id, event) {
  if (this.min != 0 && this.chosen.length <= this.min) {
    var confirmationModal = new ConfirmationModal("Mindestanzahl: " + this.min);
  } else {
    this.chosen = this.chosen.diff(id);
    this.element.children('input:hidden[value="' + id + '"]').remove();
    this.overlay.find('.chosen-items-container [data-id=' + id + ']').remove();
    this.overlay.children(".items").find('.item[data-id=' + id + ']').removeClass('active');
    this.updateChosenCounter();
  }
};

ObjectBrowser.prototype.updateChosenCounter = function () {
  var html = '';
  if (this.chosen.length > 1) html = '<strong>' + this.chosen.length + '</strong> Elemente auswählen';
  else if (this.chosen.length == 1) html = '<strong>' + this.chosen.length + '</strong> Element auswählen';
  else html = 'Keine Elemente auswählen';
  this.overlay.find('.chosen-counter').html(html);
};

ObjectBrowser.prototype.loadMore = function (loaded_ids) {
  $.ajax({
    url: '/' + this.content_type + '/' + this.content_id + '/load_more_linked_objects',
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
  });
};

ObjectBrowser.prototype.loadDetails = function (id) {
  this.selected = id;
  $.ajax({
    url: this.url + '/details',
    method: 'POST',
    dataType: 'script',
    data: JSON.stringify({
      type: this.type,
      locale: this.locale,
      key: this.key,
      definition: this.definition,
      options: this.options,
      class: this.class,
      id: id
    }),
    contentType: 'application/json'
  });
};

ObjectBrowser.prototype.resetOverlay = function () {
  this.overlay.find('.object-browser-search').val('');
  this.overlay.find('.chosen-items-container .item').remove();
  this.chosen = [];
  this.search = "";
  this.excluded = [];
  this.page = 1;
};

ObjectBrowser.prototype.setPreselected = function () {
  this.overlay.find('.chosen-items-container').html(this.element.find('> .media-thumbs > .object-thumbs > .item').clone(true));

  this.chosen = $.map(this.element.find('> .media-thumbs > .object-thumbs > .item'), (val, i) => $(val).data('id'));
}

ObjectBrowser.prototype.openOverlay = function (ev) {
  this.resetOverlay();
  this.setPreselected();
  this.updateChosenCounter();

  // set breadcrumb link + text
  var text = $(".breadcrumb ul li:last-child").html();
  $(".breadcrumb ul li:last-child").html(
    '<a class="close-object-browser" href="#">' +
    text +
    '</a><i class="fa fa-angle-right breadcrumb-separator" aria-hidden="true"></i>'
  );
  $(".breadcrumb ul").append(
    '<li><span class="breadcrumb-text"><i><i class="fa fa-files-o" aria-hidden="true"></i>' +
    this.label +
    " auswählen</i></span></li>"
  );

  $(".breadcrumb ul li").on("click", ".close-object-browser", event => {
    event.preventDefault();
    this.overlay.foundation("close");
  });

  $(window).on('message.object_browser onmessage.object_browser', this.import.bind(this));

  let loaded = $.map(this.element.find('> .media-thumbs > .object-thumbs > .item'), (val, i) => $(val).data('id'));

  if (this.ids.diff(loaded).length > 0) this.loadMore(loaded);

  this.element.find('> .media-thumbs > .buttons > #load_more_' + this.object_id + '_' + this.id).remove();
  this.loadObjects(false);
};

ObjectBrowser.prototype.closeOverlay = function (ev) {
  $(".breadcrumb ul li:last-child").remove();
  var text = $(".breadcrumb ul li:last-child a.close-object-browser").html();
  $(".breadcrumb ul li:last-child").html(text);
  $(".breadcrumb ul li").off("click");
  $(window).off('message.object_browser onmessage.object_browser');
  $('#content-upload-reveal').off('closed.zf.reveal');
};

ObjectBrowser.prototype.import = function (event) {
  if (event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'import') {
    var AUTH_TOKEN = $('meta[name=csrf-token]').attr('content');
    $.ajax({
      type: 'POST',
      url: '/creative_works/import',
      dataType: 'script',
      data: JSON.stringify({
        authenticity_token: AUTH_TOKEN,
        type: this.type + "_object",
        data: event.originalEvent.data.data,
        locale: this.locale,
        key: this.key,
        editable: this.editable,
        definition: this.definition,
        options: this.options,
        editable: this.editable,
        objects: this.chosen
      }),
      contentType: 'application/json'
    }).done(function (data) {
      this.overlay.find('.items .item .reveal.media-preview').each(function () {
        if ($(this).prop('id').indexOf('overlay_') == -1) $(this).prop('id', 'overlay_' + $(this).prop('id'));
      });
    }.bind(this)).always(() => {
      $('#new_' + this.id).foundation('close');
    });
  }
};

ObjectBrowser.prototype.loadObjects = function (append = true) {
  if (!append) {
    this.excluded = [];
    this.overlay.children('.items').scrollTop(0);
    this.overlay.children('.items').html('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  }
  this.overlay.find('.items .loading').show();
  this.loading = true;
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
      append: append
    }),
    contentType: 'application/json'
  }).done(data => {
    this.total = this.overlay.data("total");
    this.overlay.find('.items .item .reveal.media-preview').each(function () {
      if ($(this).prop('id').indexOf('overlay_') == -1) $(this).prop('id', 'overlay_' + $(this).prop('id'));
    });
    this.loading = false;
    if (this.overlay.children('.items').children('.item').length < this.total && (this.overlay.children('.items').children('.item').last().offset().top - this.overlay.children('.items').offset().top < this.overlay.children('.items').first().outerHeight())) {
      this.page += 1;
      this.loadObjects();
    }
  });
};

module.exports = ObjectBrowser;
