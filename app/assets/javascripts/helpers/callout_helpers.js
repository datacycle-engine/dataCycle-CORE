import { showToast } from '../components/toast_notification';

const CalloutHelpers = {
  show(text, type = '', closeable = true) {
    showToast(text, type, closeable);
  }
};

Object.freeze(CalloutHelpers);

export default CalloutHelpers;
