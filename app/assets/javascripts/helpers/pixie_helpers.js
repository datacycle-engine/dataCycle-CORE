/**
 * One pending request per image and endpoint, keyed by url and parameters. Kept across the page:
 * what a suggestion is asked for -- a thing or an uploaded asset -- cannot change while the form
 * for it is open, so an answer stays valid for as long as its wand exists.
 *
 * Capped because the upload reveal outlives one batch: applying a pixie to 20 files leaves 20
 * answers resident, and the reveal takes another 20 files without a reload. The oldest entry goes
 * first -- Map iterates in insertion order -- which is the file the user has moved past.
 */
const suggestions = new Map();
const MAX_SUGGESTIONS = 50;

// the key is the request, so a caller building the same body in another order still hits it
const suggestionKey = (url, body) =>
	`${url} ${JSON.stringify(body, Object.keys(body).sort())}`;

/**
 * Shared plumbing of the pixie components (#47879, #47881): they all fill an editor from a
 * suggestion endpoint and report failures in a callout next to it.
 */
const PixieHelpers = {
	/**
	 * Asks a suggestion endpoint for one image, once. The three text attributes of an image -- title,
	 * caption, ALT text -- are read from one and the same annotation, so the first wand clicked pays
	 * for the request and the other two read its answer.
	 *
	 * What is cached is the pending request, not its result, so two wands clicked before the first
	 * answer arrives still share it. A request that failed -- rejected, or answered with an error --
	 * is dropped again, so the next click retries instead of repeating the failure.
	 *
	 * @param url [String] the endpoint
	 * @param body [Object] its parameters, which together with the url identify the answer
	 * @return [Promise<Object>] the parsed response
	 */
	suggestion(url, body) {
		const key = suggestionKey(url, body);
		const pending = suggestions.get(key);
		if (pending) return pending;

		const request = DataCycle.httpRequest(url, { method: "POST", body })
			.then((payload) => {
				if (payload?.error) suggestions.delete(key);

				return payload;
			})
			.catch((error) => {
				suggestions.delete(key);

				throw error;
			});

		suggestions.set(key, request);
		if (suggestions.size > MAX_SUGGESTIONS)
			suggestions.delete(suggestions.keys().next().value);

		return request;
	},

	/**
	 * The answer to a request that has already been made, without making it.
	 *
	 * #suggestion would issue the request when there is nothing cached, and drops its entry again
	 * whenever one failed -- so a caller that only wants to know what someone else already asked
	 * (PixieToAllFiles#ownAnswer, reading the wand's own answer to count it) would otherwise pay
	 * for a second call to the annotation service every time the first one failed.
	 *
	 * @return [Promise<Object>|undefined] undefined when nothing was asked, or the entry is gone
	 */
	cachedSuggestion(url, body) {
		return suggestions.get(suggestionKey(url, body));
	},

	/**
	 * The flow every generate button performs: freeze what must not be clicked meanwhile, ask the
	 * endpoint, and either apply the answer, report that the service found nothing, or report why it
	 * failed -- releasing the freeze whichever way it ends.
	 *
	 * It was written out three times, once per pixie, so every fix to the flow had three sites to
	 * reach and a fourth pixie would have copied it again. What actually differs is passed in.
	 *
	 * @param request [Array(String, Object)] url and body, i.e. what PIXIES[...].request answered
	 * @param extract [Function] payload -> the values to apply; an empty array means the service
	 *   found nothing, which is an answer and not a failure
	 * @param apply [Function] called with those values
	 * @param report [Function] (text, type) -> void
	 * @param hold [Function] () -> release, called before the request
	 * @param emptyKey [String] i18n key for "the service found nothing"
	 * @param failedKey [String] i18n key for a request that failed
	 */
	async run({ request, extract, apply, report, hold, emptyKey, failedKey }) {
		const release = hold();

		try {
			const payload = await PixieHelpers.suggestion(...request);

			if (payload.error) return report(payload.error);

			const values = extract(payload);

			if (!values?.length)
				return report(await I18n.translate(emptyKey), "info");

			apply(values);
		} catch (error) {
			report(await PixieHelpers.errorMessage(error, failedKey));
		} finally {
			release();
		}
	},

	/**
	 * The callout of one form element, bound to the class its owner clears by. Every component had
	 * its own two-line pair of these, varying in nothing but that class.
	 *
	 * @return [Object] { report, clear }
	 */
	messenger(formElement, messageClass) {
		return {
			report: (text, type = "alert") =>
				PixieHelpers.renderMessage(formElement, messageClass, text, type),
			clear: () => PixieHelpers.clearMessage(formElement, messageClass),
		};
	},

	/**
	 * The editors of one form element, as the import event expects them.
	 */
	editorsIn(formElement) {
		if (!formElement) return null;

		return $(formElement).find(DataCycle.config.EditorSelectors.join(", "));
	},

	/**
	 * Renders a message into the form element. The text can come from the annotation service, so it
	 * is inserted as text and never as markup.
	 */
	renderMessage(formElement, messageClass, text, type = "alert") {
		if (!formElement || !text) return;

		PixieHelpers.clearMessage(formElement, messageClass);

		const callout = document.createElement("div");
		// .pixie-message carries the shared spacing; messageClass is what #clearMessage selects
		callout.className = `callout ${type} pixie-message ${messageClass}`;
		callout.textContent = text;
		formElement.appendChild(callout);
	},

	clearMessage(formElement, messageClass) {
		for (const message of formElement?.querySelectorAll(
			`:scope > .${messageClass}`,
		) || [])
			message.remove();
	},

	/**
	 * DataCycle.httpRequest rejects with `new Error(response.status)` and attaches the parsed body as
	 * `responseBody` only when the response was JSON. A CanCan denial or a proxy error is neither, so
	 * `error.message` is the bare status code — worthless to an editor, which is why it is only used
	 * when the translated fallback is missing too.
	 */
	async errorMessage(error, fallbackKey) {
		return (
			error?.responseBody?.error ||
			error?.responseBody?.errors?.[0]?.detail ||
			(await I18n.translate(fallbackKey)) ||
			error?.message
		);
	},
};

export default PixieHelpers;
