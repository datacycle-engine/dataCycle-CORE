module.exports = {
  get: (p, o) => p.reduce((xs, x) => (xs && xs[x] ? xs[x] : null), o),
  reject: (obj, keys) => {
    return Object.keys(obj)
      .filter(k => !keys.includes(k))
      .map(k =>
        Object.assign(
          {},
          {
            [k]: obj[k]
          }
        )
      )
      .reduce((res, o) => Object.assign(res, o), {});
  },
  select: (obj, keys) => {
    return Object.keys(obj)
      .filter(k => keys.includes(k))
      .map(k =>
        Object.assign(
          {},
          {
            [k]: obj[k]
          }
        )
      )
      .reduce((res, o) => Object.assign(res, o), {});
  },
  renameKey: (obj, old_key, new_key) => {
    if (old_key == new_key) {
      return obj;
    }
    if (obj.hasOwnProperty(old_key)) {
      obj[new_key] = obj[old_key];
      delete obj[old_key];
    }
    return obj;
  }
};
