// String Helpermethods
String.prototype.getKey = function() {
  return this.split(/[\[\]]+/)
    .filter(elem => elem && elem.length)
    .pop();
};
String.prototype.normalizeKey = function() {
  return this.replace('[]', '');
};
String.prototype.isUuid = function() {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(this);
};
String.prototype.camelize = function(separator = '_') {
  return this.split(separator)
    .map(w => w.replace(/./, m => m.toUpperCase()))
    .join('');
};
