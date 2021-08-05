import htmldiff from 'htmldiff/src/htmldiff';

export default function () {
  initJsDiff();

  $(document).on('dc:html:initialized', '*', event => {
    event.preventDefault();

    initJsDiff(event.currentTarget);
  });
}

function initJsDiff(container = document) {
  $(container)
    .find('.detail-type.string.has-changes.edit')
    .each((_index, item) => {
      if (
        !$(item).hasClass('js-diff') &&
        $(item).data('diff-before') !== undefined &&
        $(item).data('diff-after') !== undefined
      ) {
        $(item)
          .find('.detail-content')
          .html(htmldiff($(item).data('diff-before'), $(item).data('diff-after')));
      }
    });
}
