// Foundation Slider
module.exports.initialize = function() {
  var SliderArray = [];

  init();

  $(document).on('changed.dc.html', '*', event => {
    init(event.target);
  });

  function init(element = document) {
    $(element)
      .find('.slider')
      .each(function() {
        SliderArray.push(new Foundation.Slider($(this)));
      });
  }
};
