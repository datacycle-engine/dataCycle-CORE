export default class DcContentLink {
  static selector = '.detail-content .dc--contentlink';
  static className = 'dcjs-content-link';
  static lazy = true;
  constructor(element) {
    this.element = element;

    this.init();
  }
  init() {
    this.element.addEventListener('click', this.click.bind(this));
  }
  click(event) {
    event.preventDefault();

    if (this.element.dataset.href) {
      const url = `${DataCycle.config.EnginePath}/things/${this.element.dataset.href}`;
      window.open(url, '_blank');
    }
  }
}
