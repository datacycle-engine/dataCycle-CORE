module.exports = {
  methods: {
    renderError: function (type, value, event, objectType) {
      var object = this;
      var item_id = objectType + "_object_browser_error";

      $('.object-browser-error').remove();
      this.clearAllTimeouts();

      var message = "";
      if (type == "min") message = "Es " + (value == 1 ? "muss" : "müssen") + " mindestens " + value + " ausgewählt sein";
      if (type == "max") message = "Es " + (value == 1 ? "darf" : "dürfen") + " maximal " + value + " ausgewählt sein";

      var left = event.pageX - 24;
      var top = event.pageY - 64;

      var error_span = $("<span id='" + item_id + "' class='single_error object-browser-error'><strong>" + objectType + ":</strong> " + message + " <a class='close-object-browser-error' href='#'><i aria-hidden='true' class='fa fa-times'></i></a></span>").appendTo('body').css({
        left: left,
        top: top
      });

      window.setTimeout(function () {
        $('#' + item_id).remove();
      }, 2000);

      $('.close-object-browser-error').click(function (ev) {
        ev.preventDefault();
        object.clearAllTimeouts();
        $(this).closest('#' + item_id).remove();
      });
    },
    clearAllTimeouts() {
      var id = window.setTimeout(null, 0);
      while (id--) {
        window.clearTimeout(id);
      }
    }
  }
}