export default {
  updateEditors: (container = document) => {
    $(container)
      .find('.quill-editor')
      .addBack('.quill-editor')
      .each((_, elem) => {
        var hidden_field = $('#' + $(elem).attr('data-hidden-field-id'));
        var text = $(elem).find('.ql-editor').html() || '';
        if (text == '<p><br></p>') text = '';
        var changed = hidden_field.val() != text;

        if (changed) {
          $(hidden_field).val(text).trigger('change');
        }
      });
  }
};
