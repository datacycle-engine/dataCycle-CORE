import DatePicker from "./../components/date_picker";

export default function () {
	const dateSelectors = [
		"input[type=datetime-local]",
		"input[type=date]",
		"input[data-type=datepicker]",
		"input[data-type=timepicker]",
	];

	DataCycle.registerAddCallback(
		dateSelectors.map((c) => `${c}:not(.flatpickr-input)`).join(", "),
		"date-picker",
		(e) => new DatePicker(e),
	);
}
