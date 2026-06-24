import loadingIcon from "../templates/loadingIcon";

export default function () {
	$(document).on(
		"ajax:before",
		".new-content-reveal [data-remote]",
		(event) => {
			$(event.target)
				.closest(".new-content-reveal")
				.find(".new-content-form")
				.html(loadingIcon("show"));
		},
	);

	$(document).on(
		"ajax:error",
		".new-content-reveal [data-remote]",
		async (event) => {
			$(event.target)
				.closest(".new-content-reveal")
				.find(".new-content-form")
				.html(await I18n.translate("frontend.load_error"));
		},
	);
}
