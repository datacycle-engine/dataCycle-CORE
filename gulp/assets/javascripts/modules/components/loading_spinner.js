// Loading Spinner
var Spinner = function (selector) {
  this.selector = selector;
}

Spinner.prototype.show = function () {
  $(this.selector).append('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
}

Spinner.prototype.hide = function () {
  $(this.selector).find('.loading').remove();
}

module.exports = Spinner;
