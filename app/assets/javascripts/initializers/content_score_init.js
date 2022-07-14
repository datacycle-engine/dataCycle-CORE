import DomElementHelpers from '../helpers/dom_element_helpers';

function setContentScoreClass(item) {
  const value = DomElementHelpers.parseDataAttribute(item.dataset.value);
  const icon = item.querySelector('.type-number-content_score');

  if (!value || !icon) return;

  const min = DomElementHelpers.parseDataAttribute(item.dataset.min) || 0;
  const max = DomElementHelpers.parseDataAttribute(item.dataset.max) || 100;
  const rangePart = Math.floor((max - min) / 3);
  const label = item.querySelector('.attribute-label-text');
  let title = `min: ${min}, max: ${max}`;

  if (label) {
    title = `${label.title}\n\n${title}`;
    label.removeAttribute('title');
  }

  item.title = title;

  if (value > rangePart && value <= rangePart * 2) icon.classList.add('medium-score');
  else if (value > rangePart * 2) icon.classList.add('high-score');
}

export default function () {
  for (const element of document.querySelectorAll('.detail-type.content_score')) setContentScoreClass(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('detail-type') && e.classList.contains('content_score'),
    e => setContentScoreClass(e)
  ]);
}
