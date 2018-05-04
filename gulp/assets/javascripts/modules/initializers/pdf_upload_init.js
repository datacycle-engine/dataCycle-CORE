// Validate PDF File Client Side
module.exports.initialize = function () {

  if ($('.data-link-reveal input[type="file"]').length) {
    $('.data-link-reveal .selected-file .remove-file').click(event => {
      event.preventDefault();
      $(event.currentTarget).parent('.selected-file').remove();
    });

    $('.data-link-reveal input[type="file"]').on('change', event => {
      event.preventDefault();
      $(event.currentTarget).siblings('.selected-file').remove();
      $(event.currentTarget).siblings('span.warning').remove();
      $(event.currentTarget).siblings('[type="submit"]').prop('disabled', false);

      if (event.currentTarget.files[0].size > 5000000) {
        $(event.currentTarget).before('<span class="warning">Datei zu groß (max. 5MB)</span>');
        $(event.currentTarget).siblings('[type="submit"]').prop('disabled', true);
      }
      if (event.currentTarget.files[0].type != 'application/pdf') {
        $(event.currentTarget).before('<span class="warning">Falscher Dateityp (erlaubt: PDF)</span>');
        $(event.currentTarget).siblings('[type="submit"]').prop('disabled', true);
      }
    });
  }

};
