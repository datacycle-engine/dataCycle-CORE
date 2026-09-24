import BusyButtons from "../helpers/busy_buttons";
import PixieHelpers from "../helpers/pixie_helpers";
import { PIXIES, pixieContext } from "../helpers/pixies";

/**
 * imageDescriptionPixie (#47881): fills one text attribute of an image -- ALT text, title, caption
 * -- from the annotation of that image, and writes the suggestion into the editor next to the
 * button. Saving is the form's job; the pixie never persists anything itself.
 *
 * One component per button, because the button is what carries the request context. The endpoint
 * answers with every opted-in attribute at once, and the components share PixieHelpers' cache of
 * pending requests, so the three wands of one image cost a single request between them.
 */
export default class ImageDescriptionPixie {
	static selector = ".image-description-pixie-button";
	static className = "dcjs-image-description-pixie";
	static messageClass = "image-description-pixie-message";
	static pixie = PIXIES.image_description_pixie;

	constructor(element) {
		this.element = element;
		this.formElement = element.closest(".form-element");
		this.context = pixieContext(element);
		this.messenger = PixieHelpers.messenger(
			this.formElement,
			ImageDescriptionPixie.messageClass,
		);

		this.setup();
	}

	setup() {
		this.element.addEventListener("click", this.clickHandler.bind(this));
	}

	clickHandler(event) {
		event.preventDefault();
		this.suggest();
	}

	async suggest() {
		const editor = PixieHelpers.editorsIn(this.formElement);
		if (!editor?.length) return;

		const pixie = ImageDescriptionPixie.pixie;

		this.messenger.clear();

		await PixieHelpers.run({
			request: pixie.request(this.context),
			// the service keys every text per locale and the form edits one locale at a time, so
			// only the locale this editor belongs to is applied
			extract: (payload) => pixie.extract(payload, this.context),
			// no force: an attribute that already holds text asks before it is replaced, the same
			// way every other import into an editor does
			apply: ([suggestion]) =>
				editor.trigger("dc:import:data", { value: suggestion.value }),
			report: this.messenger.report,
			hold: () => BusyButtons.hold(this.element),
			emptyKey: pixie.emptyKey,
			failedKey: pixie.failedKey,
		});
	}
}
