export default {
  isVisible: function (elem) {
    return elem.offsetWidth > 0 || elem.offsetHeight > 0 || elem.getClientRects().length > 0;
  }
};
