import lodashEscape from 'lodash/escape';

const showTimeMapping = {
  alert: 10000,
  info: 8000,
  success: 5000,
  default: 5000
};

class ToastNotification {
  constructor(notificationContainer) {
    this.notificationContainer = notificationContainer;
    this.notificationContainer.classList.add('dcjs-toast-notification');
    this.setUp();
  }

  setUp() {
    this.addEventListeners();
    this.addMutationObserver();
    this.handleInitialNotifications();
  }

  addEventListeners() {}

  addMutationObserver() {
    const observer = new MutationObserver(mutations => {
      mutations.forEach(mutation => {
        if (mutation.addedNodes.length) {
          mutation.addedNodes.forEach(node => {
            if (node.classList.contains('new-notification')) {
              this.handleNotification(node);
            }
          });
        }
      });
    });

    observer.observe(this.notificationContainer, { childList: true });
  }

  handleNotification(node) {
    const text = node.dataset.text;
    const type = node.dataset.type;
    const closeable = node.hasAttribute('data-closable');

    this.showToastNotification(text, type, closeable);
    node.remove();
  }

  handleInitialNotifications() {
    this.notificationContainer.querySelectorAll('.new-notification').forEach(node => {
      this.handleNotification(node);
    });
  }

  showToastNotification(text, type = '', closeable = true) {
    showToast(text, type, closeable);
  }
}

export function showToast(text, type = '', closeable = true) {
  let showTime = showTimeMapping[type] || showTimeMapping.default;

  let autoDismiss = type !== 'alert' && type !== 'info';

  autoDismiss = closeable ? autoDismiss : true; // if not closeable, always auto dismiss. Otherwise, it would be impossible to dismiss the notification.

  const toast = document.createElement('div');
  toast.classList.add('flash-notification', 'toast-notification', type);
  toast.setAttribute('data-text', lodashEscape(text));
  toast.setAttribute('data-type', type);
  if (autoDismiss) {
    toast.setAttribute('data-auto-dismiss', '');
  }
  toast.style.setProperty('--_time', `${showTime}ms`);
  if (closeable) {
    toast.setAttribute('data-closable', '');
  }
  toast.innerHTML = `
    ${text}
    ${
      closeable
        ? `<button
            name="button"
            type="button"
            class="close-button"
            data-close
            aria-label="Dismiss alert"
          >
            <span aria-hidden="true">×</span>
          </button>`
        : ''
    }
  ${autoDismiss ? '<div class="toast-timer-bar"></div>' : ''}
  `;

  const container = document.querySelector('.flash-messages');
  container?.appendChild(toast);

  toast.addEventListener('animationend', function (event) {
    if (event.animationName === 'slideOut') {
      toast.remove();
    }
  });
}

export default ToastNotification;
