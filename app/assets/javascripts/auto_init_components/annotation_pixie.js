import BusyButtons from "../helpers/busy_buttons";
import PixieHelpers from "../helpers/pixie_helpers";
import { PIXIES, pixieContext } from "../helpers/pixies";

/**
 * annotationPixie (#47879): fetches classification suggestions per concept scheme for the image
 * currently being edited and writes them into the editor of that scheme. Saving is the form's job
 * -- the pixie never persists anything itself.
 *
 * The component is auto-inited on each of its generate buttons and listens on the whole form: its
 * editors are ordinary classification editors among the form's own attributes, and a scheme with a
 * dedicated attribute renders its button in that editor.
 */
export default class AnnotationPixie {
	static selector = ".annotation-pixie-classify";
	static className = "dcjs-annotation-pixie";
	static messageClass = "annotation-pixie-message";
	static pixie = PIXIES.annotation_pixie;

	constructor(button) {
		this.form = button.closest("form");
		this.setup();
	}

	/**
	 * One listener per form, on the form: every button in it is answered by the same handler, and
	 * a re-rendered editor brings its button back to be auto-inited again -- so the flag keeps a
	 * second instance from attaching a second handler and applying every suggestion twice. The
	 * handler that stays reads the image off the button that was clicked, so it answers for
	 * whichever buttons the form holds now.
	 */
	setup() {
		if (!this.form || this.form.dataset.annotationPixieBound) return;

		this.form.dataset.annotationPixieBound = "true";
		this.form.addEventListener("click", this.clickHandler.bind(this));
	}

	clickHandler(event) {
		const classifyButton = event.target.closest(".annotation-pixie-classify");
		if (!classifyButton) return;

		event.preventDefault();
		this.classify(classifyButton);
	}

	/**
	 * One request per button, i.e. per concept scheme: the classification webhook accepts exactly
	 * one tree per call. The image does not change while the form is open, so a second click on the
	 * same button re-applies the answer instead of paying for it again -- and a click during the
	 * first request joins it rather than starting a second (PixieHelpers.suggestion).
	 */
	async classify(button) {
		const formElement = button.closest(".form-element");
		const editor = PixieHelpers.editorsIn(formElement);
		if (!editor?.length) return;

		const { report, clear } = PixieHelpers.messenger(
			formElement,
			AnnotationPixie.messageClass,
		);
		const pixie = AnnotationPixie.pixie;
		const context = pixieContext(button);

		clear();

		await PixieHelpers.run({
			request: pixie.request(context),
			extract: (payload) => pixie.extract(payload, context),
			// the select2 import path resolves classification ids into pre-selected, removable
			// chips, so suggestions stay editable by hand
			apply: (values) =>
				editor.trigger("dc:import:data", {
					value: values.map((value) => value.value),
				}),
			report,
			// the service answers in seconds, so every other action button in the form is frozen
			// until this one has written its suggestion
			hold: () => BusyButtons.hold(button),
			emptyKey: pixie.emptyKey,
			failedKey: pixie.failedKey,
		});
	}
}
