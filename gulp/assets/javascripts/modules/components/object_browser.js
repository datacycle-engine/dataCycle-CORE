// Object Browser Module
var Objectbrowser = function ($selector) {
  this.$element = $selector;
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
  this.page = 1;
  this.loading = false;
  this.search = "";
  this.url = "/objectbrowser";
  this.total = 0;
  this.setup();
};

Objectbrowser.prototype.setup = function () {
  this.$overlay.on('open.zf.reveal', this.open_overlay.bind(this));
  this.$overlay.on('closed.zf.reveal', this.close_overlay.bind(this));

  this.$overlay.children(".items").on("scroll", function (event) {
    var elem = $(event.currentTarget);

    if (elem[0].scrollHeight - elem.scrollTop() - 100 <= elem.outerHeight() && !this.loading && this.$overlay.children('.items').children('.item').length < this.total) {
      this.page += 1;
      this.load_objects();
    }
  }.bind(this));
};

Objectbrowser.prototype.open_overlay = function (ev) {
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

  $(".breadcrumb ul li").on(
    "click",
    ".close-object-browser",
    function (e) {
      e.preventDefault();
      this.$emit("close");
    }.bind(this)
  );

  this.load_objects();
};

Objectbrowser.prototype.close_overlay = function (ev) {
  $(window).scrollTop(this.scrollTop);
  $(".reveal-blur").removeClass("show");

  // remove breadcrumb link + text
  $(".breadcrumb ul li:last-child").remove();
  var text = $(".breadcrumb ul li:last-child a.close-object-browser").html();
  $(".breadcrumb ul li:last-child").html(text);
};

Objectbrowser.prototype.load_objects = function () {
  this.loading = true;
  $.post(this.url, {
    page: this.page,
    per: this.per,
    type: this.type,
    language: this.language,
    overlay_id: '#object_browser_' + this.id,
    key: this.key,
    definition: this.definition,
    options: this.options,
    search: this.search
  }, function (data) {
    this.total = this.$overlay.data("total");
    this.loading = false;
    if (this.$overlay.children('.items').children('.item').length < this.total && (this.$overlay.children('.items').children('.item').last().offset().top - this.$overlay.children('.items').offset().top < this.$overlay.children('.items').first().outerHeight())) {
      this.page += 1;
      this.load_objects();
    }
  }.bind(this));
};

module.exports = Objectbrowser;
