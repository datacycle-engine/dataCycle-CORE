import CalloutHelpers from '../../helpers/callout_helpers';
import ConfirmationModal from '../confirmation_modal';

class LifeCylceButton {
  constructor(item) {
    this.item = item;
    this.dcLifeCylceButton = true;
    this.lifeCycleContainer = this.item.closest('.content-pool-buttons');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.setLifeCycle.bind(this));
  }
  setLifeCycle(event) {
    event.preventDefault();
    event.stopPropagation();

    DataCycle.disableElement(this.item);

    if (this.item.dataset.confirm) {
      new ConfirmationModal({
        text: this.item.dataset.confirm,
        cancelable: true,
        confirmationClass: 'alert',
        confirmationCallback: this.sendRequest.bind(this),
        cancelCallback: () => {
          DataCycle.enableElement(this.item);
        }
      });
    } else {
      this.sendRequest();
    }
  }
  sendRequest() {
    DataCycle.httpRequest({
      url: this.item.href,
      method: 'PATCH',
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        if (data && data.html) {
          this.lifeCycleContainer.insertAdjacentHTML('beforebegin', data.html);
          this.lifeCycleContainer.remove();
        }
        if (data && data.error) CalloutHelpers.show(data.error, 'alert');
        if (data && data.success) CalloutHelpers.show(data.success, 'success');
      })
      .finally(() => {
        DataCycle.enableElement(this.item);
      });
  }
}

export default LifeCylceButton;
