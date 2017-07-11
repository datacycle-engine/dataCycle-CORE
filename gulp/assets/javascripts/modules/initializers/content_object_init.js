// Reveal Blur 
module.exports.initialize = function () {

  $('.contentObject').on('click', '.removeContentObject', function (ev) {
    ev.preventDefault();

    $(this).parent().remove();

  });

};