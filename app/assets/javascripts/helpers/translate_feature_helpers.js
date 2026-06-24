import { showCallout } from "./callout_helpers";

export function translateText(label, text, targetLocale, sourceLocale = null) {
	const params = {
		text: typeof text === "string" ? text.trim() : text,
		target_locale: targetLocale,
	};

	if (sourceLocale) params.source_locale = sourceLocale;

	return DataCycle.httpRequest("/things/translate_text", {
		method: "POST",
		body: params,
	}).catch(async (error) => {
		let errorMessage = await I18n.translate(
			"frontend.split_view.translate_error",
			{ label: label },
		);
		const responseMessage =
			error?.responseJSON?.error || error?.responseBody?.error;
		if (responseMessage) errorMessage += `<br><i>${responseMessage}</i>`;

		showCallout(errorMessage, "alert");
	});
}
