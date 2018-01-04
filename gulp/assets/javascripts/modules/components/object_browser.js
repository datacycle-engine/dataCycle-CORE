// Object Browser Module
var ObjectBrowser = function (selector) {
  this.element = selector;
  this.id = selector.prop('id');
  this.scrollTop = 0;
  this.overlay = $('#object_browser_' + this.id);
  this.label = $('[for=' + this.id + ']').text();
  this.per = 25;
  this.type = selector.data('type');
  this.language = selector.data('language');
  this.key = selector.data('key');
  this.definition = selector.data('definition');
  this.options = selector.data('options');
  this.class = selector.data('class');
  this.max = selector.data('max');
  this.min = selector.data('min');
  this.page = 1;
  this.loading = false;
  this.search = "";
  this.url = "/object_browser";
  this.total = 0;
  this.chosen = selector.data('objects');
  this.setup();
};

ObjectBrowser.prototype.setup = function () {
  var self = this;

  // initialize all eventhandlers
  this.overlay.on('open.zf.reveal', this.open_overlay.bind(this));
  this.overlay.on('closed.zf.reveal', this.close_overlay.bind(this));

  this.overlay.children(".items").on("scroll", function (event) {
    var elem = $(event.currentTarget);

    if (elem[0].scrollHeight - elem.scrollTop() - 200 <= elem.outerHeight() && !this.loading && this.overlay.children('.items').children('.item').length < this.total) {
      this.page += 1;
      this.load_objects();
    }
  }.bind(this));

  this.overlay.find('.object-browser-search').on('change', function (event) {
    event.preventDefault();
    self.search = $(this).val();
    self.page = 1;
    self.load_objects(false);
  });

  this.overlay.find('.chosen-items-container').on('click', '.item', function (event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    self.load_details($(this).data('id'));
  });

  this.overlay.children(".items").on('click', '.item', function (event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    self.load_details($(this).data('id'));
    if (self.chosen.indexOf($(this).data('id')) == -1) {
      self.add_object($(this).data('id'), $(this).clone(true), event);
    } else {
      self.remove_object($(this).data('id'), event);
    }
  });

  this.element.on('click', '.delete-thumbnail', function (event) {
    event.preventDefault();
    event.stopPropagation();
    if (self.min != 0 && self.chosen.length <= self.min) {
      self.show_confirmation(self.element, event, "Mindestanzahl: " + self.min, false);
    } else {
      self.chosen.splice(self.chosen.indexOf($(this).parent().data('id')), 1);
      $('.reveal-overlay > #media_reveal_' + $(this).parent().data('id')).parent('.reveal-overlay').remove();
      $(this).parent().remove();
    }
  });

  this.overlay.find('.chosen-items-container').on('click', '.delete-thumbnail', function (event) {
    event.preventDefault();
    event.stopPropagation();
    self.remove_object($(this).parent().data('id'), event);
  });

  this.overlay.find('.buttons .save-object-browser').on('click', function (event) {
    event.preventDefault();
    this.set_chosen();
    this.overlay.foundation("close");
  }.bind(this));

  this.element.on('import-data', function (event, data) {
    var new_items = this.get_delta(this.chosen, data.ids);
    if (new_items.length > 0 && ((this.chosen.length + new_items.length) <= this.max || this.max == 0)) {
      $.ajax({
        url: this.url + '/find',
        method: 'POST',
        data: JSON.stringify({
          type: this.type,
          language: this.language,
          object_browser_id: '#' + this.id,
          key: this.key,
          definition: this.definition,
          options: this.options,
          ids: data.ids,
          class: this.class,
          objects: this.chosen
        }),
        contentType: 'application/json'
      }).done(function (return_data) {
        this.chosen = this.chosen.concat(data.ids.filter(function (elem) {
          return this.chosen.indexOf(elem) === -1;
        }.bind(this)));

        this.element.find('.object-thumbs .item .reveal.media-preview').each(function () {
          $(this).foundation();
        });

      }.bind(this));
    } else if (this.max != 0 && (this.chosen.length + new_items.length) > this.max) {
      self.show_confirmation(this.element, event, "Maximalanzahl: " + self.max, false);
    }
  }.bind(this));

  this.overlay.on('import-complete', function (event, data) {
    this.overlay.children('.items').find('[data-id=' + data.id + ']').get(0).scrollIntoView({
      behavior: "smooth"
    });
    this.add_object(data.id, this.overlay.find('[data-id=' + data.id + ']').clone(true), event);
  }.bind(this));

  $('#new_' + this.id).on('open.zf.reveal', function (event) {
    if ($(this).find('iframe').length > 0) {
      $(this).append('<div class="loading-iframe"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
      $(this).find('iframe').on('lazyloaded', function () {
        $(this).find('.loading-iframe').remove();
      }.bind(this));
    }

    $(this).find('form').on('submit', function (ev, data) {
      if (data != undefined && data.valid) {
        ev.preventDefault();
        ev.stopPropagation();
        ev.stopImmediatePropagation();
        var form_data = $(this).serializeJSON();
        $.extend(form_data, {
          type: self.type,
          language: self.language,
          overlay_id: '#object_browser_' + self.id,
          key: self.key,
          definition: self.definition,
          options: self.options,
          class: self.class,
          objects: self.chosen,
          new_overlay_id: '#new_' + self.id
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
    if ($(this).children('iframe').hasClass('lazyloaded')) $(this).children('iframe').removeClass('lazyloaded').addClass('lazyload');
    if ($(this).children('iframe').hasClass('lazyloading')) $(this).children('iframe').removeClass('lazyloading').addClass('lazyload');
  });
};

ObjectBrowser.prototype.set_chosen = function () {
  this.element.children('.media-thumbs').children('.object-thumbs').html(this.overlay.find('.chosen-items-container .item').clone()).children('.item').find('.reveal.media-preview').each(function () {
    if ($(this).prop('id').indexOf('overlay_') != -1) $(this).prop('id', $(this).prop('id').replace('overlay_', ''));
    $(this).foundation();
  });
};

ObjectBrowser.prototype.add_object = function (id, element, event) {
  if (this.max != 0 && this.chosen.length >= this.max) {
    this.show_confirmation(this.overlay, event, "Maximalanzahl: " + this.max, false);
  } else {
    this.chosen.push(id);
    this.overlay.find('.chosen-items-container').append(element);
    this.overlay.children(".items").find('.item[data-id=' + id + ']').addClass('active');
    this.update_chosen_counter();
  }
};

ObjectBrowser.prototype.remove_object = function (id, event) {
  if (this.min != 0 && this.chosen.length <= this.min) {
    this.show_confirmation(this.overlay, event, "Mindestanzahl: " + this.min, false);
  } else {
    this.chosen.splice(this.chosen.indexOf(id), 1);
    this.overlay.find('.chosen-items-container [data-id=' + id + ']').remove();
    this.overlay.children(".items").find('.item[data-id=' + id + ']').removeClass('active');
    this.update_chosen_counter();
  }
};

ObjectBrowser.prototype.update_chosen_counter = function () {
  var html = '';
  if (this.chosen.length > 1) html = '<strong>' + this.chosen.length + '</strong> Elemente auswählen';
  else if (this.chosen.length == 1) html = '<strong>' + this.chosen.length + '</strong> Element auswählen';
  else html = 'Keine Elemente auswählen';
  this.overlay.find('.chosen-counter').html(html);
};

ObjectBrowser.prototype.load_details = function (id) {
  $.ajax({
    url: this.url + '/details',
    method: 'POST',
    data: JSON.stringify({
      type: this.type,
      language: this.language,
      overlay_id: '#object_browser_' + this.id,
      key: this.key,
      definition: this.definition,
      options: this.options,
      class: this.class,
      id: id
    }),
    contentType: 'application/json'
  });
};

ObjectBrowser.prototype.reset_overlay = function () {
  this.overlay.find('.object-browser-search').val('');
  this.overlay.find('.chosen-items-container .item').remove();
  this.chosen = this.element.data('objects');
  this.search = "";
  this.page = 1;
};

ObjectBrowser.prototype.set_preselected = function () {
  this.overlay.find('.chosen-items-container').html(this.element.children('.media-thumbs').children('.object-thumbs').children('.item').clone(true));
  this.chosen = $.map(this.element.children('.media-thumbs').children('.object-thumbs').children('.item'), function (val, i) {
    return $(val).data('id');
  });
}

ObjectBrowser.prototype.open_overlay = function (ev) {
  this.reset_overlay();
  this.set_preselected();
  this.update_chosen_counter();

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

  this.load_objects(false);
};

ObjectBrowser.prototype.close_overlay = function (ev) {
  $(window).scrollTop(this.scrollTop);
  $(".reveal-blur").removeClass("show");
  $(".breadcrumb ul li:last-child").remove();
  var text = $(".breadcrumb ul li:last-child a.close-object-browser").html();
  $(".breadcrumb ul li:last-child").html(text);
  $(".breadcrumb ul li").off("click");
  $(window).off('message onmessage');
};

ObjectBrowser.prototype.import = function (event) {
  $('#new_' + this.id).foundation('close');
  if (event.originalEvent.data.action == 'import') {
    var AUTH_TOKEN = $('meta[name=csrf-token]').attr('content');
    $.ajax({
      type: 'POST',
      url: '/creative_works/import',
      data: JSON.stringify({
        authenticity_token: AUTH_TOKEN,
        type: this.type + "_object",
        data: event.originalEvent.data.data,
        language: this.language,
        overlay_id: '#object_browser_' + this.id,
        key: this.key,
        definition: this.definition,
        options: this.options,
        objects: this.chosen
      }),
      contentType: "application/json"
    }).done(function (data) {
      this.overlay.find('.items .item .reveal.media-preview').each(function () {
        if ($(this).prop('id').indexOf('overlay_') == -1) $(this).prop('id', 'overlay_' + $(this).prop('id'));
      });
    }.bind(this));
  }
};

ObjectBrowser.prototype.load_objects = function (append = true) {
  if (!append) {
    this.overlay.children('.items').scrollTop(0);
    this.overlay.children('.items').html('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  }
  this.overlay.find('.items .loading').show();
  this.loading = true;
  $.ajax({
    url: this.url + '/show',
    method: 'POST',
    data: JSON.stringify({
      page: this.page,
      per: this.per,
      type: this.type,
      language: this.language,
      overlay_id: '#object_browser_' + this.id,
      key: this.key,
      definition: this.definition,
      options: this.options,
      search: this.search,
      objects: this.chosen
    }),
    contentType: 'application/json'
  }).done(function (data) {
    this.total = this.overlay.data("total");
    this.overlay.find('.items .item .reveal.media-preview').each(function () {
      if ($(this).prop('id').indexOf('overlay_') == -1) $(this).prop('id', 'overlay_' + $(this).prop('id'));
    });
    this.loading = false;
    if (this.overlay.children('.items').children('.item').length < this.total && (this.overlay.children('.items').children('.item').last().offset().top - this.overlay.children('.items').offset().top < this.overlay.children('.items').first().outerHeight())) {
      this.page += 1;
      this.load_objects();
    }
  }.bind(this));
};

ObjectBrowser.prototype.get_delta = function (arr1, arr2) {
  var delta = [];
  for (var i = 0; i < arr2.length; i++) {
    if (arr1.indexOf(arr2[i]) === -1) delta.push(arr2[i]);
  }
  return delta;
};

ObjectBrowser.prototype.show_confirmation = function (parent, event, text, abort = true) {
  parent.find('.confirmation').remove();
  var html = '<div class="confirmation" style="position: absolute; transition: none;"><span>';
  html += text
  html += '</span><div class="buttons">';
  if (abort) html += '<button class="button abort" type="button">Abbrechen</button>';
  html += '<button class="button ok" type="button">Ok</button></div></div>';
  parent.append(html);
  parent.find('.confirmation').css({
    top: event.pageY - parent.offset().top - parent.find('.confirmation').outerHeight() - 20,
    left: event.pageX - parent.offset().left - 50
  });

  parent.find('.confirmation .button.ok').click(function (event) {
    event.preventDefault();
    parent.find('.confirmation').remove();
  });

  if (abort) {
    parent.find('.confirmation .button.abort').click(function (event) {
      event.preventDefault();
      parent.find('.confirmation').remove();
    });
  }
};

module.exports = ObjectBrowser;
