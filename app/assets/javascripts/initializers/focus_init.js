export default function () {
	// dc multi-value-button -> opening_time editor
	$(document).on("click", ".dc-multi-value-label:not(:disabled)", (ev) => {
		const values = Array.from(
			ev.target.parentElement.querySelectorAll(
				":scope input.dc-multi-value-button",
			),
		);
		const newIndex = (values.findIndex((e) => e.checked) || 0) + 1;
		const selectedOption = values[newIndex >= values.length ? 0 : newIndex];

		if (!selectedOption.disabled && !selectedOption.getAttribute("readonly"))
			selectedOption.checked = true;
	});
}
