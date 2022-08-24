import DomElementHelpers from '../helpers/dom_element_helpers';

async function setContentScoreClass(item) {
  item.dcContentScoreClass = true;
  const embeddedParent = item.closest('.detail-type.embedded');
  const value = parseInt(DomElementHelpers.parseDataAttribute(item.dataset.value));
  const icon = item.querySelector('.type-number-content_score, .type-string-content_score');

  if (!value || !icon) return;

  const min = parseInt(
    embeddedParent
      ? embeddedParent.querySelector('.detail-type.min_value').dataset.value
      : DomElementHelpers.parseDataAttribute(item.dataset.min) || 0
  );
  const max = parseInt(
    embeddedParent
      ? embeddedParent.querySelector('.detail-type.max_value').dataset.value
      : DomElementHelpers.parseDataAttribute(item.dataset.max) || 100
  );
  const rangePart = Math.floor((max - min) / 3);
  const label = item.querySelector('.attribute-label-text');
  let title = `min: ${min}, max: ${max}`;

  if (embeddedParent) {
    await $(
      embeddedParent.querySelector(
        '.translatable-attribute-container[data-attribute-key="name"] > .translatable-attribute.remote-render.active'
      )
    ).triggerHandler('dc:remote:forceRenderTranslations');

    const dynamicLabel = embeddedParent.querySelector(
      '.translatable-attribute-container[data-attribute-key="name"] > .translatable-attribute.active .detail-type'
    );

    if (dynamicLabel && dynamicLabel.dataset.value) {
      label.innerText = dynamicLabel.dataset.value;
      label.title = dynamicLabel.dataset.value;
    }
  }

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
    e =>
      e.classList.contains('detail-type') &&
      e.classList.contains('content_score') &&
      !e.hasOwnProperty('dcContentScoreClass'),
    e => setContentScoreClass(e)
  ]);
}
