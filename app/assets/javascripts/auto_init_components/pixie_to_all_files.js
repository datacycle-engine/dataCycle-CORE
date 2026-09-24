import BusyButtons from "../helpers/busy_buttons";
import { showCallout } from "../helpers/callout_helpers";
import PixieHelpers from "../helpers/pixie_helpers";
import { PIXIES, pixieContext } from "../helpers/pixies";

/**
 * The upload mask's second button beside a pixie's wand (#47879, #47881): "apply the pixie to all
 * files". A suggestion belongs to one image, so unlike copying an attribute to every file this asks
 * the service for every uploaded file by its own asset -- in one call where the pixie's service
 * classifies a batch, one call per file where it does not.
 *
 * The file being edited is filled through the pixie's own generate button, i.e. the path that is
 * already there; the others receive their values as form fields, which is how the uploader carries
 * the attributes of a file that has no form open.
 *
 * New_content_dialog renders the button beside the wand and copies that button's data attributes
 * onto it, so which pixie and which attribute is a question this button answers itself.
 */
export default class PixieToAllFiles {
	static selector = ".pixie-to-all-files";
	static className = "dcjs-pixie-to-all-files";

	constructor(button) {
		this.button = button;
		this.form = button.closest("form");
		this.pixie = PIXIES[button.dataset.pixie];
		this.formElement = button.closest(".form-element");
		this.generateButton = button.parentElement?.querySelector(
			".pixie-generate-button:not(.pixie-to-all-files)",
		);

		if (this.pixie && this.generateButton)
			this.button.addEventListener("click", this.click.bind(this));
	}

	/**
	 * The name the suggestion is submitted under, taken from the editor rather than rebuilt: a
	 * translated attribute carries the locale in its name, and a classification editor the [] that
	 * makes it a list.
	 */
	get fieldName() {
		const locale = this.button.dataset.locale;
		const inputs = this.formElement.querySelectorAll('[name^="thing"]');

		for (const input of inputs)
			if (!locale || input.name.includes(`[${locale}]`)) return input.name;

		return inputs[0]?.name;
	}

	async click(event) {
		event.preventDefault();

		// the wand beside this button stays operable: it is clicked below for the file being
		// edited, and a frozen button would drop that click
		const release = BusyButtons.hold(this.button, {
			except: [this.generateButton],
		});

		try {
			// the file being edited: its editors are filled, so the suggestion stays reviewable and
			// removable there like any other
			this.generateButton.click();

			// triggerHandler rather than trigger: the form is not an ancestor of the uploader's
			// elements, so there is nothing to bubble to -- and it hands back what the handler
			// returns, which is the promise the other files are being asked in
			await $(this.form).triggerHandler("dc:upload:applyPixieToAllFiles", {
				prepare: this.prepare.bind(this),
				fieldsForFile: this.fieldsForFile.bind(this),
			});

			await this.reportEmpty();
		} finally {
			release();
		}
	}

	/**
	 * Asks for every image at once, where the pixie's service takes a batch. Called before the
	 * per-file pass, whose lookups then read from this one answer instead of asking again.
	 *
	 * A pixie without a batch endpoint leaves this a no-op and keeps the request per file.
	 *
	 * @param assetIds [Array<String>] the images the values are wanted for
	 */
	async prepare(assetIds) {
		this.batch = null;
		this.batchFailed = false;
		this.failureReported = false;
		this.failureMessage = null;
		this.emptyFiles = [];

		if (!this.pixie.batchRequest || !assetIds?.length) return;

		const request = this.pixie.batchRequest(
			pixieContext(this.button),
			assetIds,
		);

		try {
			const payload = await PixieHelpers.suggestion(...request);

			// passed on as it came: PixieHelpers.errorMessage prefers a translated fallback over
			// Error#message, so wrapping the service's own text in `new Error` lost it and the
			// batch reported something the wand never says
			if (payload.error) {
				this.batchFailed = true;
				await this.reportFailure(payload.error);

				return;
			}

			this.batch = payload;
		} catch (error) {
			// the batch is the whole request for every file, so a failure is reported once here
			// rather than turned into one failing request per file
			this.batchFailed = true;
			await this.reportFailure(error);
		}
	}

	/**
	 * @param file [AssetFile] one of the other uploaded files
	 * @return [Array|null] the {name, value, text} fields that file submits for this attribute, or
	 *   null when the service suggested nothing for its image
	 */
	async fieldsForFile(file) {
		const name = this.fieldName;
		if (!name) return null;

		const answer = await this.suggestionFor(file.assetId());

		// Whatever came back about this image is said in this image's own form: its own error where
		// the request failed, and the pixie's "found nothing" where it answered with nothing. A
		// toast alone reports the run, which leaves every file but the edited one looking untouched
		// rather than answered.
		if (answer.error) {
			file.rememberPixieMessage?.(this.messageTarget, answer.error, "alert");

			return null;
		}

		if (!answer.values?.length) {
			this.emptyFiles.push(file);

			return null;
		}

		// what a previous run said about this file no longer holds: it has a suggestion now, and a
		// stale "found nothing" sitting under the attribute that just got filled is worse than no
		// message at all -- it is replayed every time the form is opened
		file.forgetPixieMessage?.(this.messageTarget);

		const suggested = answer.values;

		// several concept schemes share universal_classifications, so applying one adds to what the
		// file already carries there instead of replacing it
		const kept = this.pixie.merge
			? file.attributeFieldValues?.filter(
					(field) => field.name === name && field.value,
				) || []
			: [];
		// by value, keeping the first: an entry the file already carries brings its own label, while
		// a suggestion for the same concept may carry none -- the file's attribute summary renders
		// field.text || field.value, so the classification would read as a bare uuid there.
		// Map#set overwrites, so the first entry is kept by skipping the later ones rather than by
		// the order they are inserted in
		const byValue = new Map();

		for (const field of [...kept, ...suggested.map((s) => ({ name, ...s }))])
			if (!byValue.has(field.value)) byValue.set(field.value, field);

		return [...byValue.values()];
	}

	/**
	 * What the service said about one image.
	 *
	 * An answer and a failure are told apart by which key is set rather than by an array against
	 * null: every message the service produced belongs in the form of the image it was produced
	 * for, so the error of this image has to survive the trip back rather than collapse into "no
	 * values". A batch that failed failed for every image on it, so each gets that same message.
	 *
	 * @param assetId [String] the image to ask about
	 * @return [Object] {values: Array} or {error: String}
	 */
	async suggestionFor(assetId) {
		if (this.batchFailed) return { error: this.failureMessage };
		if (this.batch)
			return { values: this.pixie.batchValues(this.batch, assetId) };

		// the same descriptor the wand asks with, for another file's asset: that file has no content
		// yet, so the thing is dropped and the asset names the image
		const context = pixieContext(this.button, { thingId: null, assetId });

		try {
			// through the shared cache: the three text attributes of a file read one annotation, so
			// applying a second one to every file asks the service for none of them again
			const payload = await PixieHelpers.suggestion(
				...this.pixie.request(context),
			);

			if (payload.error)
				return { error: await this.reportFailure(payload.error) };

			return { values: this.pixie.extract(payload, context) };
		} catch (error) {
			return { error: await this.reportFailure(error) };
		}
	}

	/**
	 * Which editor a message belongs under. The concept scheme matters because several of the
	 * annotationPixie's editors share one data-key -- they all write universal_classifications --
	 * so a message for Zielgruppen must not land under Veranstaltungskategorien.
	 *
	 * @return [Object] {key, conceptSchemeId}
	 */
	get messageTarget() {
		return {
			key: this.formElement?.dataset.key,
			conceptSchemeId: this.formElement?.dataset.conceptSchemeId,
		};
	}

	/**
	 * Says once, for the whole run, that the service found nothing -- and once per file, in that
	 * file's own form, through +AssetFile#rememberPixieMessage+.
	 *
	 * Both, because neither is enough alone: an inline callout is only seen in the form the user
	 * opens next, and a banner alone leaves every file but the edited one looking untouched rather
	 * than answered.
	 *
	 * The wording is the pixie's own ("Keine Vorschläge über der Schwelle." for the
	 * annotationPixie), the same sentence the wand puts in the form of the file it filled; this
	 * adds only how many files it holds for.
	 *
	 * A batch failure is not reported here -- it answered for no file, so there is nothing to
	 * count. A single file's failed request is, for the files that did answer: they were asked
	 * separately and their answer stands on its own.
	 */
	async reportEmpty() {
		if (!this.emptyFiles?.length) return;

		const message = await I18n.translate(this.pixie.emptyKey);
		const target = this.messageTarget;

		// each file also says it in its own form, under the attribute this ran for -- the banner
		// names how many, the form says which
		for (const file of this.emptyFiles)
			file.rememberPixieMessage?.(target, message, "info");

		// The file being edited counts too: the banner names files rather than "other files", so a
		// run that found nothing for all three has to say three. It is not what decides whether the
		// banner appears though -- that file says it in its own form, so a run affecting it alone
		// needs no banner to repeat it.
		const own = await this.ownAnswer();
		const count =
			this.emptyFiles.length +
			(own && !own.error && !own.values?.length ? 1 : 0);

		showCallout(
			await I18n.translate("frontend.upload.pixie_to_all_empty", {
				count,
				message,
			}),
			"info",
		);
	}

	/**
	 * What the wand answered for the file being edited.
	 *
	 * Read from the cache the wand itself filled, never asked for: this button carries the wand's
	 * own dataset (NewContentDialog#pixieToAllButton copies it), so it builds the very request the
	 * wand made and finds that request's answer.
	 *
	 * @return [Object|null] {values: Array} or {error: String}, null when nothing is cached
	 */
	async ownAnswer() {
		const context = pixieContext(this.button);
		// #cachedSuggestion rather than #suggestion: the entry is dropped again whenever a request
		// failed, so asking through #suggestion would send a second one to the annotation service
		// for exactly the runs where the wand had already failed -- and again once the cache's
		// 50 entry cap has evicted it. Unknown means uncounted, which is the safe way to be wrong.
		const pending = PixieHelpers.cachedSuggestion(
			...this.pixie.request(context),
		);
		if (!pending) return null;

		try {
			const payload = await pending;

			if (payload.error) return { error: payload.error };

			return { values: this.pixie.extract(payload, context) };
		} catch {
			return null;
		}
	}

	/**
	 * One callout for the whole run, whatever shape the failure arrives in.
	 *
	 * A pixie with no batch endpoint asks per file (imageDescriptionPixie: PixieLens annotates one
	 * image per call), so 20 files produced 20 callouts where the batch path shows one -- and an
	 * error carried in the payload rather than thrown produced none at all, so the two failure
	 * shapes reported differently.
	 *
	 * The message is still resolved for a failure whose callout is suppressed, because it is what
	 * the image it belongs to shows in its own form -- only the toast is once per run.
	 *
	 * Word for word what the wand says for the file being edited: the pixie's own +failedKey+, and
	 * a message the service sent verbatim. One failure of one pixie read as two different things
	 * otherwise -- "Fehler beim Abruf des Content Classifiers." in the form the button was clicked
	 * in and a message about applying to all files in every other form, for one and the same
	 * failed request.
	 *
	 * @param error [Error|String] what came back
	 * @return [String] the message, for the image this failure was about
	 */
	async reportFailure(error) {
		const message =
			typeof error === "string" && error.length
				? error
				: await PixieHelpers.errorMessage(error, this.pixie.failedKey);

		// the batch is one request for every image, so a later image reads this rather than its own
		this.failureMessage ||= message;

		if (!this.failureReported) {
			this.failureReported = true;
			showCallout(message, "error");
		}

		return message;
	}
}
