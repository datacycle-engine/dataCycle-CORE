import Counter from "./../components/word_counter";

export default function () {
	DataCycle.registerAddCallback(
		"input[type=text].form-control:not(.flatpickr-input)",
		"counter",
		(e) => new Counter(e).start(),
	);
}
