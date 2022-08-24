import QualityScore from '../components/quality_score';

function checkForNewVisibleElements(entries, observer) {
  for (const entry of entries) {
    if (!entry.isIntersecting) continue;

    observer.unobserve(entry.target);
    entry.target.qualityScore.loadScore();
  }
}

export default function () {
  const intersectionObserver = new IntersectionObserver(checkForNewVisibleElements, {
    rootMargin: '0px 0px 50px 0px',
    threshold: 0.1
  });

  for (const elem of document.getElementsByClassName('attribute-quality-score')) {
    new QualityScore(elem);
    intersectionObserver.observe(elem);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('attribute-quality-score') && !e.hasOwnProperty('dcQualityScore'),
    e => {
      new QualityScore(e);
      intersectionObserver.observe(e);
    }
  ]);
}
