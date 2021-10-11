export default {
  isVisible: function (elem) {
    return elem.offsetWidth > 0 || elem.offsetHeight > 0 || elem.getClientRects().length > 0;
  },
  parseDataAttribute: function (value) {
    if (!value) return value;

    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  },
  randomId: (prefix = '') => {
    return `${prefix}_${Math.random().toString(36).slice(2)}`;
  }
};
