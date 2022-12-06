import CalloutHelpers from '../../helpers/callout_helpers';
import ConfirmationModal from '../confirmation_modal';

class LifeCylceButton {
  constructor(item) {
    this.item = item;
    this.dcLifeCylceButton = true;
    this.lifeCycleContainer = this.item.closest('.content-pool-buttons');
    this.classificationsContainer = this.lifeCycleContainer.previousElementSibling;

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.setLifeCycle.bind(this));
  }
  setLifeCycle(event) {
    event.preventDefault();
    event.stopPropagation();

    this.disable();

    if (this.item.dataset.confirm) {
      new ConfirmationModal({
        text: this.item.dataset.confirm,
        cancelable: true,
        confirmationClass: 'alert',
        confirmationCallback: this.sendRequest.bind(this),
        cancelCallback: () => {
          this.enable();
        }
      });
    } else {
      this.sendRequest();
    }
  }
  disable() {
    DataCycle.disableElement(this.item);
    this.item.closest('.content-pool').classList.add('disabled');
  }
  enable() {
    DataCycle.enableElement(this.item);
    this.item.closest('.content-pool').classList.remove('disabled');
  }
  sendRequest() {
    DataCycle.httpRequest({
      url: this.item.href,
      method: 'PATCH',
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        if (data && data.classifications_html) {
          if (this.classificationsContainer.classList.contains('content-header-classifications')) {
            this.classificationsContainer.insertAdjacentHTML('beforebegin', data.classifications_html);
            this.classificationsContainer.remove();
          } else {
            this.lifeCycleContainer.insertAdjacentHTML('beforebegin', data.classifications_html);
          }
        }
        if (data && data.life_cycle_html) {
          this.lifeCycleContainer.insertAdjacentHTML('beforebegin', data.life_cycle_html);
          this.lifeCycleContainer.remove();
        }
        if (data && data.error) CalloutHelpers.show(data.error, 'alert');
        if (data && data.success) CalloutHelpers.show(data.success, 'success');
      })
      .finally(() => {
        this.enable();
      });
  }
}

export default LifeCylceButton;
