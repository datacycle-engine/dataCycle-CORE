import ContentScore from "../components/content_score";
import LegacyContentScore from "../components/legacy_content_score";

function checkForNewVisibleElements(entries, observer) {
	for (const entry of entries) {
		if (!entry.isIntersecting) continue;

		observer.unobserve(entry.target);
		new ContentScore(entry.target);
	}
}

export default function () {
	DataCycle.initNewElements(
		".detail-type.content_score:not(.dcjs-content-score-class)",
		(e) => new LegacyContentScore(e),
	);

	const intersectionObserver = new IntersectionObserver(
		checkForNewVisibleElements,
		{
			rootMargin: "0px 0px 50px 0px",
			threshold: 0.1,
		},
	);

	DataCycle.initNewElements(
		".attribute-content-score:not(.dcjs-content-score)",
		(e) => {
			intersectionObserver.observe(e);
		},
	);
}
