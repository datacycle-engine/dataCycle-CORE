// Reveal Blur 
module.exports.initialize = function () {

  $('.contentObject .removeContentObject').on('click', function (ev) {
    ev.preventDefault();

    $(this).parent().trigger('remove-embedded-object');
    $(this).parent().remove();

  });

};