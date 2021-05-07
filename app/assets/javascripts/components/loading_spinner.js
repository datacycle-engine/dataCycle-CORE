class Spinner {
  constructor(selector) {
    this.selector = selector;
  }
  show() {
    $(this.selector).append('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
  }
  hide() {
    $(this.selector).find('.loading').remove();
  }
}

export default Spinner;
