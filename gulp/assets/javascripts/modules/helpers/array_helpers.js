// Array Helpermethods
Array.prototype.diff = function (a) {
  if (a === undefined || a === null) return this;
  if (!Array.isArray(a)) a = [a];
  return this.filter(i => a.indexOf(i) === -1);
};

Array.prototype.intersect = function (a) {
  if (a === undefined || a === null) return [];
  if (!Array.isArray(a)) a = [a];
  return this.filter(i => a.indexOf(i) !== -1);
};

Array.prototype.equal_to = function (a) {
  return (
    this.length === a.length &&
    this.filter((e, i) => a[i].name === e.name && a[i].value === e.value).length === this.length
  );
};
Array.prototype.mergeUnique = function (toMerge) {
  if (!toMerge || !toMerge.length) return this;

  return this.concat(toMerge).filter((elem, pos, arr) => arr.indexOf(elem) == pos);
};
