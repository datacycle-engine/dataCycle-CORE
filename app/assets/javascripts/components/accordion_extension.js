class AccordionExtension {
  constructor() {
    this.setup();
  }
  setup() {
    $(document).on('click', '.accordion-close-all', this.closeAll.bind(this));
    $(document).on('click', '.accordion-open-all', this.openAll.bind(this));
    $(document).on('click', '.accordion-close-children', this.closeChildren.bind(this));
    $(document).on('click', '.accordion-open-children', this.openChildren.bind(this));
  }
  closeAll(event) {
    this.closeAccordionItems(event, $(event.currentTarget.closest('.inner-container')));
  }
  closeChildren(event) {
    $(event.currentTarget)
      .closest('.embedded-viewer[data-accordion], .embedded-object[data-accordion]')
      .foundation('up', $(event.currentTarget).closest('.accordion-title').siblings('.accordion-content'));

    this.closeAccordionItems(event, $(event.currentTarget.closest('.accordion-item')));
  }
  openAll(event) {
    this.openAccordionItems(event, $(event.currentTarget.closest('.inner-container')));
  }
  openChildren(event) {
    $(event.currentTarget)
      .closest('.embedded-viewer[data-accordion], .embedded-object[data-accordion]')
      .foundation('down', $(event.currentTarget).closest('.accordion-title').siblings('.accordion-content'));

    this.openAccordionItems(event, $(event.currentTarget.closest('.accordion-item')));
  }
  closeAccordionItems(event, container) {
    event.preventDefault();
    event.stopPropagation();

    $(container)
      .find('.embedded-viewer[data-accordion], .embedded-object[data-accordion]')
      .addBack('.embedded-viewer[data-accordion], .embedded-object[data-accordion]')
      .each((_index, accordion) => {
        $(accordion).foundation('up', $(accordion).find('> .accordion-item > .accordion-content'));
      });
  }
  openAccordionItems(event, container) {
    event.preventDefault();
    event.stopPropagation();

    $(container)
      .find('.embedded-viewer[data-accordion], .embedded-object[data-accordion]')
      .addBack('.embedded-viewer[data-accordion], .embedded-object[data-accordion]')
      .each((_index, accordion) => {
        $(accordion).foundation('down', $(accordion).find('> .accordion-item > .accordion-content'));
      });
  }
}

export default AccordionExtension;
