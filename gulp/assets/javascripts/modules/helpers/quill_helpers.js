// QuillJS Helpermethods
module.exports = {
  update_value: (editor) => {
    var hidden_field = $('#' + $(editor).attr('data-hidden-field-id'));
    var text = $(editor).find('.ql-editor').html();
    var changed = (hidden_field.val() != text);

    if (changed) {
      $(hidden_field).val(text).trigger('change');
    }
    return changed;
  }
};
