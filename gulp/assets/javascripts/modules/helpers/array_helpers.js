// Array Helpermethods
Array.prototype.diff = function (a) {
  return this.filter(i => a.indexOf(i) === -1);
};

Array.prototype.intersect = function (a) {
  return this.filter(i => a.indexOf(i) !== -1);
};

Array.prototype.equal_to = function (a) {
  return this.length === a.length && this.filter((e, i) => a[i].name === e.name && a[i].value === e.value).length === this.length;
};
