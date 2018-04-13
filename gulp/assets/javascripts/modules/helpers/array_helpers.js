// Array Helpermethods
Array.prototype.diff = function (a) {
  return this.filter(i => a.indexOf(i) === -1);
};

Array.prototype.intersect = function (a) {
  return this.filter(i => a.indexOf(i) !== -1);
};

Array.prototype.equal_to = function (a) {
  return this.length === a.length && this.filter((e, i) => {
    if (a[i].name !== e.name || a[i].value !== e.value) {
      console.log(a);
      console.log(this);
    }
    return a[i].name === e.name && a[i].value === e.value;
  }).length === this.length;

  return this.length === a.length && this.filter(i => a.findIndex(e => e.name === i.name && e.value === i.value) !== -1).length === this.length;
};
