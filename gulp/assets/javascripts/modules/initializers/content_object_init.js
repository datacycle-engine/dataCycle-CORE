// Reveal Blur 
module.exports.initialize = function () {

  $('.contentObject').on('click', '.addContentObject', function (ev) {
    ev.preventDefault();

    var cloneID = $(this).prev('.content-object-item').attr('id').match(/\d+/);
    var type = $(this).prev('.content-object-item').attr('id').replace(/\d+/, '');
    var clone = $(document.getElementById(type + 'template').innerHTML);

    //$(this).before(changeIDs(clone, ++cloneID));
    //clone.trigger('clone-added');

  });

  $('.contentObject').on('click', '.removeContentObject', function (ev) {
    ev.preventDefault();

    $(this).parent().remove();

  });


  function changeIDs(clone, newID) {

    clone.attr('id', function (i, txt) {
      return txt.replace(/\d+/, newID);
    });

    clone.find('label[for]').attr('for', function (i, txt) {
      return txt.replace(/\d+/, newID);
    });

    clone.find('input[name]').attr('name', function (i, txt) {
      return txt.replace(/\d+/, newID);
    }).val('');

    clone.find('input[id]').attr('id', function (i, txt) {
      return txt.replace(/\d+/, newID);
    }).val('');

    clone.find('.quill-editor').attr('id', function (i, txt) {
      return txt.replace(/\d+/, newID);
    }).attr('data-hidden-field-id', function (i, txt) {
      return txt.replace(/\d+/, newID);
    });
    clone.find('.quill-editor').html('').siblings('.ql-toolbar').remove();

    clone.find('object-browser').attr('hidden-name', function (i, txt) {
      return txt.replace(/\d+/, newID);
    });

    clone.find('object-browser template[slot=item]').contents().find('input[name]').attr('name', function (i, txt) {
      return txt.replace(/\d+/, newID);
    });

    return clone;
  }
};