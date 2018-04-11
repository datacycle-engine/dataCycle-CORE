// Array Helpermethods
Array.prototype.diff = function (a) {
  return this.filter(function (i) {
    return a.indexOf(i) === -1;
  });
};

Array.prototype.intersect = function (a) {
  return this.filter(function (i) {
    return a.indexOf(i) !== -1;
  });
};
