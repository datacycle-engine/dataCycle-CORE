var ConfirmationModal = require('./../components/confirmation_modal');
var Sortable = require('sortablejs');

// Embedded Object Module
class EmbeddedObject {
  constructor(selector) {
    this.element = selector;
    this.page = 1;
    this.id = this.element.prop('id');
    this.locale = this.element.data('locale') || 'de';
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
    this.setup();
  }
  setup() {
    this.setupSwappableButtons();
    this.sortable = new Sortable(this.element[0], {
      group: this.id,
      handle: '.draggable-handle',
      draggable: '.content-object-item.draggable_' + this.id
    });
    if (this.write && (this.max == 0 || this.element.children('.content-object-item').length < this.max))
      $(this.element)
        .find('> .buttons > #add_' + this.id)
        .show();
    this.element.off('reinit-event-handlers').on('reinit-event-handlers', this.addEventHandlers.bind(this));
    this.element.off('dc:import:data').on(
      'dc:import:data',
      function(event, data) {
        let page = data.page || 1;
        let new_items = data.value.diff(
          this.element
            .children('.content-object-item')
            .map((index, elem) => $(elem).data('id'))
            .get()
        );
        if (
          this.write &&
          (this.max == 0 || this.element.children('.content-object-item').length < this.max) &&
          new_items.length > 0
        ) {
          this.renderEmbeddedObjects('render', new_items, data.locale);
        } else if (this.write && this.max != 0 && ids.length + new_items.length > this.max) {
          var confirmationModal = new ConfirmationModal({ text: 'Maximalanzahl: ' + this.max });
        }
      }.bind(this)
    );
    this.addEventHandlers();
  }
  setSwapClasses(object) {
    if ($(object).index() == 0)
      $(object)
        .find('> .embedded-header > .swap-button.swap-prev')
        .addClass('disabled');
    else
      $(object)
        .find('> .embedded-header > .swap-button.swap-prev')
        .removeClass('disabled');

    if ($(object).index() >= this.element.children('.content-object-item').length - 1)
      $(object)
        .find('> .embedded-header > .swap-button.swap-next')
        .addClass('disabled');
    else
      $(object)
        .find('> .embedded-header > .swap-button.swap-next')
        .removeClass('disabled');
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
  renderEmbeddedObjects(type, ids = [], locale = null) {
    let index = this.index;
    if (type == 'render') this.index += ids.diff(this.ids).length;
    else if (type == 'new') this.index++;

    this.element
      .find('> .buttons > button')
      .prop('disabled', true)
      .find('.fa')
      .css('display', 'inline-block');
    $.ajax({
      url: this.url + '/' + type + '_embedded_object',
      method: 'GET',
      dataType: 'script',
      contentType: 'application/json',
      data: {
        index: index,
        locale: this.locale,
        attribute_locale: locale,
        key: this.key,
        definition: this.definition,
        options: this.options,
        content_id: this.content_id,
        content_type: this.content_type,
        object_ids: ids
      }
    }).done(data => {
      if (ids.length > 0) this.ids = this.ids.concat(ids.diff(this.ids));
      this.update();
      this.addEventHandlers();
    });
  }
  addEventHandlers() {
    var self = this;
    this.element
      .find('> .buttons > #add_' + this.id)
      .off('click')
      .on('click', event => {
        this.renderEmbeddedObjects('new');
      });
    this.element.children('.content-object-item').each((index, element) => {
      $(element)
        .children('.removeContentObject')
        .off('click')
        .on('click', this.handleRemoveEvent.bind(this));
    });
  }
  handleRemoveEvent(event) {
    event.preventDefault();
    let element = $(event.target).closest('.content-object-item');
    if ($(event.target).data('confirm-delete') != undefined) {
      new ConfirmationModal({
        text: $(event.target).data('confirm-delete'),
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
  }
  update() {
    if (this.max != 0 && this.element.children('.content-object-item').length >= this.max) {
      this.element.find('> .buttons > #add_' + this.id).hide();
    } else if (this.write) {
      this.element.find('> .buttons > #add_' + this.id).show();
    }
    if (this.min != 0 && this.element.children('.content-object-item').length <= this.min) {
      this.element
        .children('.content-object-item')
        .children('.removeContentObject')
        .hide();
    } else if (this.write) {
      this.element
        .children('.content-object-item')
        .children('.removeContentObject')
        .show();
    }
    if (this.element.children('.content-object-item').length == 0) {
      this.element.append('<input type="hidden" value="" id="' + this.id + '_default" name="' + this.key + '[]">');
    } else {
      this.element.find('input[type=hidden]#' + this.id + '_default').remove();
    }

    this.element.children('.content-object-item').each((_, elem) => this.setSwapClasses(elem));
  }
}

module.exports = EmbeddedObject;
