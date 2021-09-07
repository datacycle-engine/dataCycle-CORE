import Control from 'ol/control/control';

class RemoveAllFeaturesControl extends Control {
  constructor(opt_options) {
    const options = opt_options || {};

    const element = document.createElement('div');
    element.className = 'ol-control ol-unselectable remove-primary-feature';

    const button = document.createElement('a');
    button.className = 'remove-feature-button';
    I18n.translate('actions.remove_feature').then(text => (button.title = text));
    element.appendChild(button);

    const icon = document.createElement('i');
    icon.className = 'fa fa-trash';
    button.appendChild(icon);

    super({
      element: element,
      target: options.target
    });

    this.initializeEventHandlers();
  }
  initializeEventHandlers() {
    $(this.element).on('click', '.remove-feature-button', this.triggerResetEvent.bind(this));
  }
  triggerResetEvent(e) {
    e.preventDefault();
    e.stopPropagation();

    $(this.map_.viewport_).closest('.geographic-map').trigger('dc:map:resetPrimaryFeature');
  }
}

export default RemoveAllFeaturesControl;
