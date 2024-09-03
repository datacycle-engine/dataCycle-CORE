import ContentScore from "../components/content_score";
import LegacyContentScore from "../components/legacy_content_score";

export default function () {
	DataCycle.registerAddCallback(
		".detail-type.content_score",
		"content-score-class",
		(e) => new LegacyContentScore(e),
	);

	DataCycle.registerLazyAddCallback(
		".attribute-content-score",
		"content-score",
		(e) => {
			new ContentScore(e);
		},
	);
}
