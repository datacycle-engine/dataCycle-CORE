import htmldiff from 'htmldiff/src/htmldiff';

export default function () {
  DataCycle.initNewElements('.detail-type.string.has-changes.edit:not(.dcjs-diff-content)', diffContent.bind(this));
}

function diffContent(textField) {
  textField.classList.add('dcjs-diff-content');
  const detailContent = textField.querySelector('.detail-content');

  if (!detailContent) return;

  detailContent.innerHTML = htmldiff(textField.dataset.diffBefore, textField.dataset.diffAfter);
}
