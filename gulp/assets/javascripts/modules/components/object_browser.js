var ConfirmationModal = require('./../components/confirmation_modal');

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
  this.language = selector.data('language');
  this.key = selector.data('key');
  this.definition = selector.data('definition');
  this.options = selector.data('options');
  this.class = selector.data('class');
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
  this.chosen = this.ids;
  this.selected = '';
  this.setup();
};

ObjectBrowser.prototype.setup = function () {
  var self = this;

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
      self.chosen.splice(self.chosen.indexOf($(this).parent().data('id')), 1);
      self.ids.splice(self.ids.indexOf($(this).parent().data('id')), 1);
      self.index--;
      $('.reveal-overlay > #media_reveal_' + $(this).parent().data('id')).parent('.reveal-overlay').remove();
      $(this).parent().remove();
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

  this.element.on('import-data', function (event, data) {
    var new_items = data.ids.diff(this.chosen);
    if (new_items.length > 0 && ((this.chosen.length + new_items.length) <= this.max || this.max == 0)) {
      this.findObjects(new_items);
    } else if (this.max != 0 && (this.chosen.length + new_items.length) > this.max) {
      var confirmationModal = new ConfirmationModal("Maximalanzahl: " + self.max);
    }
  }.bind(this));

  this.element.find('> .media-thumbs > .buttons > #load_more_' + this.id).off('click').on('click', event => {
    event.preventDefault();
    let page = $(event.currentTarget).data('page');

    this.findObjects(this.ids.slice(this.index, this.index + this.per), page);
  });

  this.overlay.on('import-complete', function (event, data) {
    this.overlay.children('.items').find('[data-id=' + data.id + ']').get(0).scrollIntoView({
      behavior: "smooth"
    });
    this.addObject(data.id, this.overlay.find('[data-id=' + data.id + ']').clone(true), event);
  }.bind(this));

  $('#new_' + this.id).on('open.zf.reveal', function (event) {
    $(this).find('form').on('submit', function (ev, data) {
      if (data != undefined && data.valid) {
        ev.preventDefault();
        ev.stopPropagation();
        ev.stopImmediatePropagation();
        var form_data = $(this).serializeJSON();
        $.extend(form_data, {
          type: self.type,
          language: self.language,
          key: self.key,
          definition: self.definition,
          options: self.options,
          class: self.class,
          objects: self.chosen,
        });

        $.ajax({
          url: $(this).prop('action'),
          method: 'POST',
          data: JSON.stringify(form_data),
          dataType: 'script',
          contentType: 'application/json'
        });
      } else if (data == undefined) {
        ev.preventDefault();
        ev.stopPropagation();
        ev.stopImmediatePropagation();
        $(this).trigger('submit', {
          object_browser: true
        });
      };
    });
  });

  $('#new_' + this.id).on('closed.zf.reveal', function (event) {
    $("body").addClass("is-reveal-open");
  });
};

ObjectBrowser.prototype.findObjects = function (ids, page = 1) {
  $.ajax({
    url: this.url + '/find',
    method: 'POST',
    dataType: 'script',
    data: JSON.stringify({
      type: this.type,
      language: this.language,
      key: this.key,
      definition: this.definition,
      options: this.options,
      ids: ids,
      class: this.class,
      objects: this.chosen,
      page: page
    }),
    contentType: 'application/json'
  }).done(return_data => {
    this.chosen = this.chosen.concat(ids.diff(this.chosen));
    this.index += ids.length;
    if (this.element.find('> .media-thumbs > .object-thumbs > .item').length >= this.ids.length) {
      this.element.find('> .media-thumbs > .buttons > #load_more_' + this.id).remove();
    }
    this.updateChosenCounter();
    this.element.find('.object-thumbs .item .reveal.media-preview').each(function () {
      $(this).foundation();
    });
  });
};

ObjectBrowser.prototype.setChosen = function () {
  this.element.children('.media-thumbs').children('.object-thumbs').html(this.overlay.find('.chosen-items-container .item').clone()).children('.item').find('.reveal.media-preview').each(function () {
    if ($(this).prop('id').indexOf('overlay_') != -1) $(this).prop('id', $(this).prop('id').replace('overlay_', ''));
    $(this).foundation();
  });
};

ObjectBrowser.prototype.addObject = function (id, element, event) {
  if (this.max != 0 && this.chosen.length >= this.max) {
    var confirmationModal = new ConfirmationModal("Maximalanzahl: " + this.max);
  } else {
    this.chosen.push(id);
    this.overlay.find('.chosen-items-container').append(element);
    this.overlay.children(".items").find('.item[data-id=' + id + ']').addClass('active');
    this.updateChosenCounter();
  }
};

ObjectBrowser.prototype.removeObject = function (id, event) {
  if (this.min != 0 && this.chosen.length <= this.min) {
    var confirmationModal = new ConfirmationModal("Mindestanzahl: " + this.min);
  } else {
    this.chosen.splice(this.chosen.indexOf(id), 1);
    this.ids.splice(this.ids.indexOf(id), 1);
    this.index--;
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

ObjectBrowser.prototype.loadDetails = function (id) {
  this.selected = id;
  $.ajax({
    url: this.url + '/details',
    method: 'POST',
    dataType: 'script',
    data: JSON.stringify({
      type: this.type,
      language: this.language,
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
  this.chosen = this.element.data('objects');
  this.search = "";
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

  this.scrollTop = $(window).scrollTop();
  window.scrollTo(0, 0);
  $(".reveal-blur").addClass("show");

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

  $(".breadcrumb ul li").on("click", ".close-object-browser", function (e) {
    e.preventDefault();
    this.overlay.foundation("close");
  }.bind(this));

  $(window).on('message onmessage', this.import.bind(this));

  let pre_selected = this.ids.diff($.map(this.element.find('> .media-thumbs > .object-thumbs > .item'), (val, i) => $(val).data('id')));

  if (pre_selected.length > 0) this.findObjects(pre_selected);

  this.element.find('> .media-thumbs > .buttons > #load_more_' + this.id).remove();
  this.loadObjects(false);
};

ObjectBrowser.prototype.closeOverlay = function (ev) {
  $(window).scrollTop(this.scrollTop);
  $(".reveal-blur").removeClass("show");
  $(".breadcrumb ul li:last-child").remove();
  var text = $(".breadcrumb ul li:last-child a.close-object-browser").html();
  $(".breadcrumb ul li:last-child").html(text);
  $(".breadcrumb ul li").off("click");
  $(window).off('message onmessage', this.import.bind(this));
};

ObjectBrowser.prototype.import = function (event) {
  $('#new_' + this.id).foundation('close');
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
        language: this.language,
        key: this.key,
        definition: this.definition,
        options: this.options,
        objects: this.chosen
      }),
      contentType: 'application/json'
    }).done(function (data) {
      this.overlay.find('.items .item .reveal.media-preview').each(function () {
        if ($(this).prop('id').indexOf('overlay_') == -1) $(this).prop('id', 'overlay_' + $(this).prop('id'));
      });
    }.bind(this));
  }
};

ObjectBrowser.prototype.loadObjects = function (append = true) {
  if (!append) {
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
      language: this.language,
      key: this.key,
      definition: this.definition,
      options: this.options,
      search: this.search,
      objects: this.chosen,
      editable: this.editable,
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
