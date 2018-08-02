// String Helpermethods
String.prototype.get_key = function () {
  return this.replace(/(^.*\[|\].*$)/g, '');
};
