import DomElementHelpers from '../helpers/dom_element_helpers';
import ContentScore from '../components/content_score';

async function setContentScoreClass(item) {
  item.classList.add('dcjs-content-score-class');
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

function checkForNewVisibleElements(entries, observer) {
  for (const entry of entries) {
    if (!entry.isIntersecting) continue;

    observer.unobserve(entry.target);
    entry.target.contentScore.loadScore();
  }
}

export default function () {
  const intersectionObserver = new IntersectionObserver(checkForNewVisibleElements, {
    rootMargin: '0px 0px 50px 0px',
    threshold: 0.1
  });

  for (const elem of document.getElementsByClassName('attribute-content-score')) {
    new ContentScore(elem);
    intersectionObserver.observe(elem);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('attribute-content-score') && !e.classList.contains('dcjs-content-score'),
    e => {
      new ContentScore(e);
      intersectionObserver.observe(e);
    }
  ]);

  // legacy content_score
  for (const element of document.querySelectorAll('.detail-type.content_score')) setContentScoreClass(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('detail-type') &&
      e.classList.contains('content_score') &&
      !e.classList.contains('dcjs-content-score-class'),
    e => setContentScoreClass(e)
  ]);
}
