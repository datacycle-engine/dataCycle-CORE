import htmldiff from 'htmldiff/src/htmldiff';

export default function () {
  for (const field of document.querySelectorAll('.detail-type.string.has-changes.edit')) {
    diffContent(field);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('detail-type') &&
      e.classList.contains('string') &&
      e.classList.contains('has-changes') &&
      e.classList.contains('edit'),
    diffContent
  ]);
}

function diffContent(textField) {
  const detailContent = textField.querySelector('.detail-content');

  if (!detailContent) return;

  detailContent.innerHTML = htmldiff(textField.dataset.diffBefore, textField.dataset.diffAfter);
}
