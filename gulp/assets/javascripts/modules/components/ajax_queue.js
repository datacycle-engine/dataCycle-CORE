// Ajax Callback Queue
var AjaxQueue = function () {
  this.requests = [];
};

AjaxQueue.prototype.queue = function (deferred, callback) {
  this.requests.push(deferred);
  $.when.apply(null, this.requests).then(callback);
}

module.exports = AjaxQueue;
