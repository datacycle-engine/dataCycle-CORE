import ConfirmationModal from '../confirmation_modal';

class ClassificationDestroyButton {
  constructor(item) {
    this.item = item;
    this.dcClassificationDestroyButton = true;

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.destroy.bind(this));
  }
  destroy(event) {
    event.preventDefault();
    event.stopPropagation();

    DataCycle.disableElement(this.item);

    new ConfirmationModal({
      text: this.item.dataset.confirm,
      confirmationClass: 'alert',
      cancelable: true,
      confirmationCallback: () => {
        DataCycle.httpRequest({
          url: this.item.href,
          method: 'delete',
          dataType: 'json',
          contentType: 'application/json'
        })
          .then(() => {
            this.item.closest('li').remove();
          })
          .catch(() => {
            DataCycle.enableElement(this.item);
          });
      },
      cancelCallback: () => {
        DataCycle.enableElement(this.item);
      }
    });
  }
}

export default ClassificationDestroyButton;
