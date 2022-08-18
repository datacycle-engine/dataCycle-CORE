class AccordionExtension {
  constructor() {
    this.setup();
  }
  setup() {
    $(document).on('click', '.accordion-close-all', this.closeChildren.bind(this));
    $(document).on('click', '.accordion-open-all', this.openChildren.bind(this));
    $(document).on('click', '.accordion-close-children', this.closeChildren.bind(this));
    $(document).on('click', '.accordion-open-children', this.openChildren.bind(this));
  }
  closeChildren(event) {
    this.closeAccordionItems(
      event,
      $(
        event.currentTarget.closest('.form-element.embedded_object, .embedded-viewer[data-accordion], .inner-container')
      )
    );
  }
  openChildren(event) {
    this.openAccordionItems(
      event,
      $(
        event.currentTarget.closest('.form-element.embedded_object, .embedded-viewer[data-accordion], .inner-container')
      )
    );
  }
  closeAccordionItems(event, container) {
    event.preventDefault();
    event.stopPropagation();

    $(container)
      .find('.embedded-viewer[data-accordion], .embedded-object[data-accordion], .attribute-group[data-accordion]')
      .addBack('.embedded-viewer[data-accordion], .embedded-object[data-accordion], .attribute-group[data-accordion]')
      .each((_index, accordion) => {
        $(accordion).foundation('up', $(accordion).find('> .accordion-item > .accordion-content'));
      });
  }
  openAccordionItems(event, container) {
    event.preventDefault();
    event.stopPropagation();

    $(container)
      .find('.embedded-viewer[data-accordion], .embedded-object[data-accordion], .attribute-group[data-accordion]')
      .addBack('.embedded-viewer[data-accordion], .embedded-object[data-accordion], .attribute-group[data-accordion]')
      .each((_index, accordion) => {
        $(accordion).foundation('down', $(accordion).find('> .accordion-item > .accordion-content'));
      });
  }
}

export default AccordionExtension;
