// Array Helpermethods
Array.prototype.diff = function (a) {
  if (!Array.isArray(a)) return this;
  return this.filter(i => a.indexOf(i) === -1);
};

Array.prototype.intersect = function (a) {
  if (!Array.isArray(a)) return [];
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
Array.prototype.mergeUniqueFormValues = function (toMerge) {
  if (!toMerge || !toMerge.length) return this;

  let tmpArray = [...this];

  for (let i = 0; i < toMerge.length; i++) {
    if (!tmpArray.find(e => e.name === toMerge[i].name && e.value === toMerge[i].value)) {
      tmpArray.splice(
        tmpArray.lastIndexOfFieldName(
          toMerge[i].name.substring(0, toMerge[i].name.replace('[]', '').lastIndexOf('['))
        ) + 1,
        0,
        toMerge[i]
      );
    }
  }

  return tmpArray;
};
Array.prototype.lastIndexOfFieldName = function (name) {
  if (!name || !name.length) return -1;

  for (let i = this.length - 1; i >= 0; i--) {
    if (this[i].name.includes(name)) return i;
  }
  return this.lastIndexOfFieldName(name.substring(0, name.lastIndexOf('[')));
};
