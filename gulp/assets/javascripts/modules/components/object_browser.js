// Object Browser Module
var Objectbrowser = function ($selector) {
  this.$element = $($selector);
  this.id = $($selector).prop('id');
  this.scrollTop = 0;
  this.$overlay = $('#object_browser_' + this.id);
  this.label = $('[for=' + this.id + ']').text();
  this.per = 25;
  this.type = $($selector).data('type');
  this.language = $($selector).data('language');
  this.key = $($selector).data('key');
  this.definition = $($selector).data('definition');
  this.options = $($selector).data('options');
  this.class = $($selector).data('class');
  this.page = 1;
  this.loading = false;
  this.search = "";
  this.url = "/objectbrowser";
  this.total = 0;
  this.chosen = $($selector).data('objects');
  this.setup();
};

Objectbrowser.prototype.setup = function () {
  console.log(this.chosen);
  var that = this;
  this.$overlay.on('open.zf.reveal', this.open_overlay.bind(this));
  this.$overlay.on('closed.zf.reveal', this.close_overlay.bind(this));

  this.$overlay.children(".items").on("scroll", function (event) {
    var elem = $(event.currentTarget);

    if (elem[0].scrollHeight - elem.scrollTop() - 100 <= elem.outerHeight() && !this.loading && this.$overlay.children('.items').children('.item').length < this.total) {
      this.page += 1;
      this.load_objects();
    }
  }.bind(this));

  this.$overlay.find('.object-browser-search').on('change', function (event) {
    event.preventDefault();
    that.search = $(this).val();
    that.load_objects(false);
  });

  this.$overlay.find('.chosen-items-container').on('click', '.item', function (event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    that.load_details($(this).data('id'));
  });

  this.$overlay.children(".items").on('click', '.item', function (event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    that.load_details($(this).data('id'));
    if (that.chosen.indexOf($(this).data('id')) == -1) {
      that.add_object($(this).data('id'), $(this).clone());
    } else {
      that.remove_object($(this).data('id'));
    }
  });

  this.$element.on('click', '.delete-thumbnail', function (event) {
    event.preventDefault();

  });

  this.$overlay.find('.chosen-items-container').on('click', '.delete-thumbnail', function (event) {
    event.preventDefault();
    event.stopPropagation();
    that.remove_object($(this).parent().data('id'));
  });

  this.$overlay.find('.buttons .save-object-browser').on('click', function (event) {
    event.preventDefault();
    this.set_chosen();
    this.$overlay.foundation("close");
  }.bind(this));
};

Objectbrowser.prototype.set_chosen = function () {
  this.$element.find('.object-thumbs').html(this.$overlay.find('.chosen-items-container .item').clone());
  this.$element.find('.object-thumbs .item .reveal').foundation();
  this.$element.find('.object-thumbs .item').foundation();
};

Objectbrowser.prototype.add_object = function (id, $element) {
  this.chosen.push(id);
  this.$overlay.find('.chosen-items-container').append($element);
  this.$overlay.children(".items").find('.item[data-id=' + id + ']').addClass('active');
};

Objectbrowser.prototype.remove_object = function (id) {
  this.chosen.splice(this.chosen.indexOf(id), 1);
  this.$overlay.find('.chosen-items-container [data-id=' + id + ']').remove();
  this.$overlay.children(".items").find('.item[data-id=' + id + ']').removeClass('active');
};

Objectbrowser.prototype.load_details = function (id) {
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

Objectbrowser.prototype.reset_overlay = function () {
  this.$overlay.find('.object-browser-search').val('');
  this.$overlay.find('.chosen-items-container .item').remove();
  this.chosen = this.$element.data('objects');
  this.search = "";
  this.page = 1;
};

Objectbrowser.prototype.set_preselected = function () {
  this.$overlay.find('.chosen-items-container').html(this.$element.find('.object-thumbs .item').clone());
}

Objectbrowser.prototype.open_overlay = function (ev) {
  this.reset_overlay();
  this.set_preselected();

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
    this.$overlay.foundation("close");
  }.bind(this));

  this.load_objects(false);
};

Objectbrowser.prototype.close_overlay = function (ev) {
  $(window).scrollTop(this.scrollTop);
  $(".reveal-blur").removeClass("show");

  // remove breadcrumb link + text
  $(".breadcrumb ul li:last-child").remove();
  var text = $(".breadcrumb ul li:last-child a.close-object-browser").html();
  $(".breadcrumb ul li:last-child").html(text);
  $(".breadcrumb ul li").off("click");
};

Objectbrowser.prototype.load_objects = function (append = true) {
  if (!append) {
    this.$overlay.children('.items').scrollTop(0);
    this.$overlay.children('.items').html('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  }
  this.$overlay.find('.items .loading').show();
  this.loading = true;
  $.ajax({
    url: this.url,
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
    this.total = this.$overlay.data("total");
    this.loading = false;
    if (this.$overlay.children('.items').children('.item').length < this.total && (this.$overlay.children('.items').children('.item').last().offset().top - this.$overlay.children('.items').offset().top < this.$overlay.children('.items').first().outerHeight())) {
      this.page += 1;
      this.load_objects();
    }
  }.bind(this));
};

module.exports = Objectbrowser;
