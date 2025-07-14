import throttle from "lodash/throttle";

export default class TurboStreamThrottle {
  constructor() {
    this.throttles = {};
    this.throttledUpdate = {};

    addEventListener(
      "turbo:before-stream-render",
      this.#throttleHandler.bind(this),
    );
  }

  throttleUpdate(key, element) {
    if (Object.hasOwn(this.throttles, key)) this.throttles[key](element);
  }

  throttleInterval(event) {
    return (
      (Number.parseInt(event.detail.newStream.dataset.throttle, 10) || 1) * 1000
    );
  }

  throttleKey(event, interval) {
    return `${event.detail.newStream.action}-${event.detail.newStream.target}-${interval}`;
  }

  initThrottledUpdate(key, interval) {
    if (!Object.hasOwn(this.throttledUpdate, key))
      this.throttledUpdate[key] = throttle(this.throttleUpdate, interval, {
        leading: true,
        trailing: true,
      });
  }

  #throttleHandler(event) {
    if (event.detail.newStream.hasAttribute("data-throttle")) {
      const interval = this.throttleInterval(event);
      const key = this.throttleKey(event, interval);
      this.initThrottledUpdate(key, interval);
      this.throttles[key] = event.detail.render;
      event.detail.render = this.throttledUpdate[key].bind(this, key);
    }
  }
}
