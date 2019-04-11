// Ajax Callback Queue
class AjaxQueue {
  constructor() {
    this.requests = [];
  }
  queue(deferred, callback) {
    this.requests.push(deferred);
    $.when.apply(null, this.requests).then(callback);
  }
}

module.exports = AjaxQueue;
