// Foundation Slider
module.exports.initialize = function () {

  var SliderArray = [];

  $('.slider').each(function () {
    SliderArray.push(new Foundation.Slider($(this)));
  });

  $(document).on('clone-added', '.content-object-item', function () {

    $(this).find('.slider').each(function () {
      SliderArray.push(new Foundation.Slider($(this)));
    });
  });

};