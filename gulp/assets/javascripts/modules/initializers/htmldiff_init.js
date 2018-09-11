var htmldiff = require('htmldiff/src/htmldiff');

module.exports.initialize = function () {

  if ($('.detail-type.string.has-changes.edit').length) {
    $('.detail-type.string.has-changes.edit').each((index, item) => {
      if ($(item).data('diff-before') !== undefined && $(item).data('diff-after') !== undefined) {
        $(item).find('.detail-content').html(htmldiff($(item).data('diff-before'), $(item).data('diff-after')));
      }
    });
  }

};
