class EmbeddedTitle {
  constructor(container = document) {
    this.$container = $(container);
    this.observer = new MutationObserver(this.observeForNewContent.bind(this));
    this.observerConfig = { attributes: false, characterData: false, subtree: true, childList: true };

    this.init();
  }
  init() {
    this.observer.observe(document, this.observerConfig);

    this.$container.on(
      'change dc:embedded:changeTitle',
      '.form-element.is-embedded-title',
      this.updateEmbeddedTitle.bind(this)
    );
  }
  updateEmbeddedTitle(event) {
    console.log('updateEmbeddedTitle');
    let value = $(event.currentTarget).find(':input').first().val();
    let $titleField = $(event.currentTarget)
      .closest('.content-object-item')
      .find('> .accordion-title > .title > .embedded-title');

    $titleField.text(value);
    $titleField.attr('title', value);

    if (value && value.length) $titleField.addClass('visible');
    else $titleField.removeClass('visible');
  }
  observeForNewContent(mutations) {
    for (let i = 0; i < mutations.length; ++i) {
      for (var j = 0; j < mutations[i].addedNodes.length; ++j) {
        if (mutations[i].addedNodes[j].nodeType !== Node.ELEMENT_NODE) continue;

        if (mutations[i].addedNodes[j].classList.contains('is-embedded-title'))
          $(mutations[i].addedNodes[j]).trigger('dc:embedded:changeTitle');
      }
    }
  }
}

export default EmbeddedTitle;
