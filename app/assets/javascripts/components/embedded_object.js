import ConfirmationModal from './../components/confirmation_modal';
import Sortable from 'sortablejs/modular/sortable.core.esm.js';
import difference from 'lodash/difference';
import union from 'lodash/union';
import intersection from 'lodash/intersection';

class EmbeddedObject {
  constructor(selector) {
    this.element = selector;
    this.addButton = this.element.siblings('.embedded-editor-header').find('> .add-content-object').first();
    this.page = 1;
    this.id = this.element.prop('id');
    this.key = this.element.data('key');
    this.label = this.element.data('label');
    this.definition = this.element.data('definition');
    this.options = this.element.data('options');
    this.max = this.element.data('max') || 0;
    this.min = this.element.data('min') || 0;
    this.write = this.element.data('write') || true;
    this.total = this.element.data('total') || 0;
    this.index = this.total;
    this.ids = this.element.data('ids') || [];
    this.per = this.element.data('per') || 5;
    this.url = this.element.data('url');
    this.sortable;
    this.content_id = this.element.data('content-id');
    this.content_type = this.element.data('content-type');
    this.locationArray = location.hash.substr(1).split('+').filter(Boolean);
    this.eventHandlers = {
      reInit: this.addEventHandlers.bind(this),
      import: this.import.bind(this),
      addItem: this.addNewItem.bind(this),
      removeItem: this.handleRemoveEvent.bind(this),
      scrollToLocationHash: this.scrollToLocationHash.bind(this)
    };
    this.addedItemsObserver = new MutationObserver(this._checkForAddedNodes.bind(this));
    this.addedItemsObserverConfig = {
      attributes: false,
      characterData: false,
      subtree: true,
      childList: true,
      attributeOldValue: false,
      characterDataOldValue: false
    };

    this.setup();
  }
  setup() {
    this.element[0].dcEmbeddedObject = true;

    this.setupSwappableButtons();
    this.sortable = new Sortable(this.element[0], {
      group: this.id,
      handle: '.draggable-handle',
      draggable: '.content-object-item.draggable_' + this.id
    });
    if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max))
      this.addButton.show();
    this.element
      .off('reinit-event-handlers', this.eventHandlers.reInit)
      .on('reinit-event-handlers', this.eventHandlers.reInit);

    this.addedItemsObserver.observe(this.element[0], this.addedItemsObserverConfig);

    this.element
      .off('dc:import:data', this.eventHandlers.import)
      .on('dc:import:data', this.eventHandlers.import)
      .addClass('dc-import-data');

    this.addEventHandlers();
    this._updateContainerClass();
  }
  _checkForConditionRecursive(node) {
    for (const child of node.children) this._checkForConditionRecursive(child);

    if (node.classList.contains('content-object-item') && !node.classList.contains('hidden')) this.setSwapClasses(node);
  }
  _checkForAddedNodes(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'childList') continue;

      for (const addedNode of mutation.addedNodes) {
        if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;

        this._checkForConditionRecursive(addedNode);
      }
    }
  }
  locale() {
    return this.element.data('locale') || 'de';
  }
  async import(_event, data) {
    let newItems = difference(
      data.value,
      this.element
        .children('.content-object-item')
        .map((_index, elem) => $(elem).data('id'))
        .get()
    );

    if (
      this.write &&
      (this.max == 0 || this.element.children('.content-object-item').length < this.max) &&
      newItems.length > 0
    ) {
      await this.renderEmbeddedObjects('split_view', newItems, data.locale, data.translate);
    } else if (this.write && this.max != 0 && ids.length + newItems.length > this.max) {
      const prefix = await I18n.translate('frontend.split_view.copy_linked_error');

      new ConfirmationModal({
        text: `${this.label}: ${prefix}${await I18n.translate('frontend.maximum_embedded', {
          data: this.max
        })}`
      });
    }
  }
  setSwapClasses(object) {
    if ($(object).index() == 0) $(object).find('> .embedded-header > .swap-button.swap-prev').addClass('disabled');
    else $(object).find('> .embedded-header > .swap-button.swap-prev').removeClass('disabled');

    if ($(object).index() >= this.element.children('.content-object-item').length - 1)
      $(object).find('> .embedded-header > .swap-button.swap-next').addClass('disabled');
    else $(object).find('> .embedded-header > .swap-button.swap-next').removeClass('disabled');
  }
  setupSwappableButtons() {
    this.element.on(
      'click',
      '> .content-object-item.draggable_' + this.id + ' > .embedded-header > .swap-button:not(.disabled)',
      event => {
        event.preventDefault();
        event.stopImmediatePropagation();

        if ($(event.currentTarget).hasClass('has-tip')) $(event.currentTarget).foundation('hide');

        let currentObject = $(event.currentTarget).closest('.content-object-item');
        let switchObject;

        if ($(event.currentTarget).hasClass('swap-prev')) {
          switchObject = currentObject.prev('.content-object-item');
          switchObject.before(currentObject);
        } else if ($(event.currentTarget).hasClass('swap-next')) {
          switchObject = currentObject.next('.content-object-item');
          switchObject.after(currentObject);
        }
        currentObject.get(0).scrollIntoView({ behavior: 'smooth' });

        this.setSwapClasses(currentObject);
        this.setSwapClasses(switchObject);
      }
    );

    this.element.children('.content-object-item').each((_, elem) => this.setSwapClasses(elem));
  }
  renderEmbeddedObjects(type, ids = [], locale = null, translate = false) {
    let index = this.index;
    if (type == 'split_view') this.index += difference(ids, this.ids).length;
    else if (type == 'new') this.index++;

    this.element.parent().addClass('loading-embedded');

    const promise = DataCycle.httpRequest({
      url: this.url + '/render_embedded_object',
      method: 'GET',
      dataType: 'script',
      contentType: 'application/json',
      data: {
        index: index,
        locale: this.locale(),
        attribute_locale: locale,
        key: this.key,
        definition: this.definition,
        options: this.options,
        content_id: this.content_id,
        content_type: this.content_type,
        object_ids: ids,
        duplicated_content: type == 'split_view',
        translate: translate
      }
    });

    promise.then(_data => {
      if (ids.length > 0) this.ids = union(this.ids, ids);
      this.update();
      this.addEventHandlers();

      this.element[0].querySelector(':scope > .content-object-item:last-of-type').scrollIntoView({
        behavior: 'smooth'
      });
    });

    return promise;
  }
  findRemoveButton(element) {
    return $(element).find('> .removeContentObject, > .form-element > .editor-block > .removeContentObject');
  }
  addEventHandlers() {
    this.addButton.off('click', this.eventHandlers.addItem).on('click', this.eventHandlers.addItem);

    this.element.children('.content-object-item').each((_index, element) => {
      this.findRemoveButton(element)
        .off('click', this.eventHandlers.removeItem)
        .on('click', this.eventHandlers.removeItem);
    });

    this.element
      .off('init.zf.accordion', this.eventHandlers.scrollToLocationHash)
      .on('init.zf.accordion', this.eventHandlers.scrollToLocationHash);
  }
  async addNewItem(event) {
    event.preventDefault();
    event.stopPropagation();

    await this.renderEmbeddedObjects('new');

    this.element.trigger('change');
  }
  handleRemoveEvent(event) {
    event.preventDefault();

    const element = $(event.currentTarget).closest('.content-object-item');

    if ($(event.currentTarget).data('confirm-delete') != undefined) {
      new ConfirmationModal({
        text: $(event.currentTarget).data('confirm-delete'),
        confirmationClass: 'alert',
        cancelable: true,
        confirmationCallback: () => {
          this.removeObject(element);
        }
      });
    } else this.removeObject(element);
  }
  removeObject(element) {
    element.trigger('dc:html:remove');

    let id = element.data('id');
    if (id !== undefined) {
      this.element.find('input:hidden[value="' + id + '"]').remove();
      this.ids = this.ids.filter(x => x != id);
    }

    element.remove();

    this.update();

    this.element.trigger('change');
  }
  update() {
    if (this.max != 0 && this.element.children('.content-object-item').length >= this.max) {
      this.addButton.hide();
    } else if (this.write) {
      this.addButton.show();
    }
    if (this.min != 0 && this.element.children('.content-object-item').length <= this.min) {
      this.findRemoveButton(this.element.children('.content-object-item')).hide();
    } else if (this.write) {
      this.findRemoveButton(this.element.children('.content-object-item')).show();
    }
    if (this.element.children('.content-object-item').length == 0) {
      this.element.append('<input type="hidden" value="" id="' + this.id + '_default" name="' + this.key + '[]">');
    } else {
      this.element.find('input[type=hidden]#' + this.id + '_default').remove();
    }

    this.element.children('.content-object-item').each((_, elem) => this.setSwapClasses(elem));
    this._updateContainerClass();
  }
  _updateContainerClass() {
    this.element[0]
      .closest('.form-element.embedded_object')
      .classList.toggle('has-items', this.element.children('.content-object-item').length > 0);
  }
  scrollToLocationHash(event) {
    event.stopPropagation();

    if (!this.locationArray || !this.locationArray.length || !this.ids || !this.ids.length) return;

    let embeddedId = intersection(this.locationArray, this.ids)[0];

    if (!embeddedId) return;

    let embeddedObject = this.element.find('.content-object-item[data-id="' + embeddedId + '"]').first();

    let topOffset = embeddedObject.offset().top - 60;

    if (embeddedObject.hasClass('hidden')) this.loadAllContents(embeddedObject);
    else if (embeddedObject.data('accordion-item') && !embeddedObject.hasClass('is-active'))
      embeddedObject.closest('[data-accordion]').foundation('down', embeddedObject.find('> .accordion-content'));

    this.element.find('> .accordion-item:not(.is-active) > .accordion-content.remote-render').each((_index, item) => {
      let remoteOptions = $(item).data('remote-options');
      delete remoteOptions.hide_embedded;
      $(item).attr('data-remote-options', JSON.stringify(remoteOptions));
    });

    window.requestAnimationFrame(() => {
      window.scrollTo({ top: topOffset, behavior: 'smooth' });
    });
  }
  loadAllContents(embeddedObject) {
    const observer = new MutationObserver(mutations => {
      for (const mutation of mutations) {
        if (mutation.type !== 'childList') continue;

        for (const addedNode of mutation.addedNodes) {
          if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;
          if (addedNode.dataset.id == embeddedObject[0].dataset.id) {
            observer.disconnect();

            $(addedNode.closest('[data-accordion]')).foundation('down', $(addedNode).find('> .accordion-content'));
          }
        }
      }
    });

    observer.observe(this.element[0], {
      attributes: false,
      characterData: false,
      subtree: true,
      childList: true,
      attributeOldValue: false,
      characterDataOldValue: false
    });

    this.element.find('> .load-more-linked-contents').get(0).click();
  }
}

export default EmbeddedObject;
