import ResultCount from "../components/result_count";

export default function () {
	DataCycle.registerAddCallback(
		".result-count",
		"result-count",
		(e) => new ResultCount(e),
	);
}
