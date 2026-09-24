import debounce from "lodash/debounce";
import ImageDetailEditorBase from "../components/image_detail_editor_base";
import { showCallout } from "../helpers/callout_helpers";
import { parseDataAttribute } from "../helpers/dom_element_helpers";
import PixieHelpers from "../helpers/pixie_helpers";

export default class FocusPointEditor extends ImageDetailEditorBase {
	static selector = ".change-focus-point-ui";
	static className = "dcjs-focus-point-editor";
	static lazy = true;
	static containerClassName = "focus-point-ui";
	static i18nNameSpace = "focus_point_editor";

	constructor(button) {
		super(button);

		this.fp = this.storedFocusPoint();
		this.thingId = this.button.dataset.thingId;
		this.fpXKey = this.button.dataset.focusPointXKey;
		this.fpYKey = this.button.dataset.focusPointYKey;
		this.sendFocusPointFunction = debounce(this.sendFocusPoint.bind(this), 200);

		this.handlers = {
			updatePosition: this.updatePosition.bind(this),
			overlayStartMove: this.overlayStartMove.bind(this),
			overlayStopMove: this.overlayStopMove.bind(this),
			measureRects: this.measureRects.bind(this),
			clearFocusPoint: this.clearFocusPoint.bind(this),
			generateFocusPoint: this.generateFocusPoint.bind(this),
		};

		this.initEditingControls();
	}

	/**
	 * The controls of an open editor -- reset, and the pixie's generate button where the annotation
	 * service can be asked about this image at all. Both are rendered by
	 * contents/_focus_feature_buttons and shown by the column's own :has(.editing) rule, so they are
	 * wired once here rather than rendered, listened to and torn down on every open: a teardown that
	 * searched the wrong container used to leave a second generate button, with a listener of its
	 * own, on each one.
	 */
	initEditingControls() {
		const controls = this.button.closest(".focus-feature-buttons");

		this.clearButton = controls?.querySelector(".focus-point-clear");
		this.generateButton = controls?.querySelector(
			".annotation-pixie-focus-point",
		);

		this.clearButton?.addEventListener("click", this.handlers.clearFocusPoint);
		this.generateButton?.addEventListener(
			"click",
			this.handlers.generateFocusPoint,
		);
	}

	/**
	 * The stored point, as the button carries it -- and where the crosshair starts. Read again
	 * whenever editing starts rather than once: publishFocusPoint writes every point this editor
	 * sends back onto the button, so re-opening it starts where the last session left off instead
	 * of at the value the page was rendered with.
	 */
	storedFocusPoint() {
		return {
			x: parseDataAttribute(this.button.dataset.focusPointX) || 0.5,
			y: parseDataAttribute(this.button.dataset.focusPointY) || 0.5,
		};
	}

	publishFocusPoint() {
		this.button.dataset.focusPointX = this.fp.x;
		this.button.dataset.focusPointY = this.fp.y;
	}

	insertFocusPointUi() {
		this.imageContainer.insertAdjacentHTML(
			"beforeend",
			`<div class="focus-point-ui">
        <div class="focus-point-ui__overlay"></div>
        <div class="focus-point-ui__crosshair"></div>
      </div>`,
		);

		this.focusPointUi = this.imageContainer.querySelector(".focus-point-ui");
		this.crossHair = this.focusPointUi.querySelector(
			".focus-point-ui__crosshair",
		);
		this.overlay = this.focusPointUi.querySelector(".focus-point-ui__overlay");
	}

	async enableEditing() {
		this.fp = this.storedFocusPoint();

		await super.enableEditing();

		this.insertFocusPointUi();
		this.initOverlayPosition();

		this.focusPointUi.addEventListener("click", this.handlers.updatePosition);
		this.focusPointUi.addEventListener(
			"mousedown",
			this.handlers.overlayStartMove,
		);
		addEventListener("mouseup", this.handlers.overlayStopMove);
	}

	async disableEditing() {
		await super.disableEditing();

		if (this.focusPointUi) {
			this.focusPointUi.removeEventListener(
				"click",
				this.handlers.updatePosition,
			);
			this.focusPointUi.removeEventListener(
				"mousedown",
				this.handlers.overlayStartMove,
			);
			removeEventListener("mouseup", this.handlers.overlayStopMove);
			// a drag that ended outside the window never saw a mouseup, so its mousemove listener is
			// still attached -- and would keep measuring a node that is about to be detached
			this.stopMoving();

			this.focusPointUi.remove();

			this.focusPointUi = null;
			this.rects = null;
		}
	}

	overlayStartMove(event) {
		event.preventDefault();

		this.measureRects();
		this.updateOverlayPosition(event.clientX, event.clientY);

		addEventListener("mousemove", this.handlers.updatePosition);
		addEventListener("resize", this.handlers.measureRects);
	}

	/**
	 * The three boxes a position is computed from: the image, and the two elements centred on the
	 * point. None of them changes size while the pointer moves, so they are measured when a drag
	 * starts rather than per event -- reading them inside #updateOverlayPosition put three forced
	 * reflows after four custom property writes, on every one of the 60 to 120 mousemoves a second
	 * a drag produces.
	 */
	measureRects() {
		if (!this.focusPointUi) return;

		this.rects = {
			focusPointUi: this.focusPointUi.getBoundingClientRect(),
			overlay: this.overlay.getBoundingClientRect(),
			crossHair: this.crossHair.getBoundingClientRect(),
		};
	}

	roundFocusPoint(value) {
		return Math.round(value * 100) / 100;
	}

	/**
	 * The scheduled frame is applied rather than dropped: a mouseup batched with the last mousemove
	 * would otherwise leave the crosshair, +this.fp+ and the PATCH on the position before it, which
	 * is the one the pointer was at a frame ago rather than where it was released. #disableEditing
	 * is the caller that wants a plain cancel -- there the node is about to be detached.
	 */
	overlayStopMove(event) {
		event.preventDefault();

		if (this.pendingFrame && this.pendingPosition)
			this.updateOverlayPosition(...this.pendingPosition);

		this.stopMoving();
	}

	stopMoving() {
		removeEventListener("mousemove", this.handlers.updatePosition);
		removeEventListener("resize", this.handlers.measureRects);

		if (this.pendingFrame) cancelAnimationFrame(this.pendingFrame);
		this.pendingFrame = null;
	}

	/**
	 * Coalesced into one frame: a mousemove arrives more often than the browser paints, so without
	 * this each of them writes four custom properties the next one invalidates again.
	 */
	updatePosition(event) {
		event.preventDefault();

		this.pendingPosition = [event.clientX, event.clientY];
		if (this.pendingFrame) return;

		this.pendingFrame = requestAnimationFrame(() => {
			this.pendingFrame = null;
			this.updateOverlayPosition(...this.pendingPosition);
		});
	}

	setOverlayPosition(olPosition) {
		this.focusPointUi.style.setProperty(
			"--focus-point-ui-overlay-left",
			`${olPosition.left}px`,
		);
		this.focusPointUi.style.setProperty(
			"--focus-point-ui-overlay-top",
			`${olPosition.top}px`,
		);
	}

	setCrossHairPosition(chPosition) {
		this.focusPointUi.style.setProperty(
			"--focus-point-ui-crosshair-left",
			`${chPosition.left}px`,
		);
		this.focusPointUi.style.setProperty(
			"--focus-point-ui-crosshair-top",
			`${chPosition.top}px`,
		);
	}

	initOverlayPosition() {
		if (!this.focusPointUi || !this.fp) return;

		this.measureRects();

		const fpRect = this.rects.focusPointUi;
		const x = this.fp.x * fpRect.width;
		const y = this.fp.y * fpRect.height;
		const olPosition = this.calculateOverlayPosition(x, y, fpRect);
		const chPosition = this.calculateCrossHairPosition(x, y, fpRect);

		if (olPosition) this.setOverlayPosition(olPosition);
		if (chPosition) this.setCrossHairPosition(chPosition);
	}

	updateOverlayPosition(absoluteX, absoluteY) {
		if (!this.focusPointUi) return;

		// a plain click never went through #overlayStartMove, so it measures once here
		if (!this.rects) this.measureRects();

		const focusPointUiRect = this.rects.focusPointUi;
		const x = absoluteX - focusPointUiRect.x;
		const y = absoluteY - focusPointUiRect.y;

		const olPosition = this.calculateOverlayPosition(x, y, focusPointUiRect);
		const chPosition = this.calculateCrossHairPosition(x, y, focusPointUiRect);
		const fp = this.calculateFocusPoint(x, y, focusPointUiRect);

		if (olPosition) this.setOverlayPosition(olPosition);
		if (chPosition) this.setCrossHairPosition(chPosition);
		if (fp) this.updateFocusPoint(fp);
	}

	updateFocusPoint(fp) {
		if (this.fp.x === fp.x && this.fp.y === fp.y) return;

		this.fp = fp;

		this.sendFocusPointFunction();
	}

	/**
	 * Both write paths of the persisting controls guard on the editor being open. CSS is what hides
	 * them, and a PATCH is what they send -- so a rule that stopped matching would otherwise write
	 * a focus point onto an image nobody is editing.
	 */
	clearFocusPoint(event) {
		event.preventDefault();
		if (!this.isEditing()) return;

		this.fp = { x: 0.5, y: 0.5 };
		this.initOverlayPosition();
		this.sendFocusPointFunction();
	}

	/**
	 * annotationPixie (#47879): the focus point the annotation service reads off the image, placed
	 * in the crosshair of this editor. From there it is the manual point in every respect -- it can
	 * be dragged, reset and is written by the same PATCH -- so the pixie needs no write path of its
	 * own, and an image the service finds no point in leaves the editor as it was.
	 *
	 * The request goes through PixieHelpers, which caches the pending request per image: the image
	 * does not change while the page is open, so clicking the button again reads the first answer
	 * instead of paying the service for it. DataCycle.disableElement cannot carry that on its own --
	 * on a button it only adds the .disabled class, and a second click during the request would
	 * still reach this method.
	 *
	 * The flow itself is PixieHelpers.run, the same one the two form-bound pixies use. What differs
	 * here is every sink: the point goes into the open editor rather than into a form editor, and a
	 * detail page has no .form-element to put a callout in, so it reports through showCallout.
	 */
	async generateFocusPoint(event) {
		event.preventDefault();
		if (!this.isEditing()) return;

		await PixieHelpers.run({
			request: ["/things/focus_point_suggestion", { thing_id: this.thingId }],
			extract: (payload) => (payload.focus_point ? [payload.focus_point] : []),
			apply: ([focusPoint]) => {
				this.fp = focusPoint;
				this.initOverlayPosition();
				this.sendFocusPointFunction();
			},
			report: (text, type = "error") => showCallout(text, type),
			hold: () => {
				DataCycle.disableElement(this.generateButton);

				return () => DataCycle.enableElement(this.generateButton);
			},
			emptyKey: "frontend.annotation_pixie.no_focus_point",
			failedKey: "frontend.annotation_pixie.focus_point_failed",
		});
	}

	sendFocusPoint() {
		DataCycle.httpRequest(`/things/${this.thingId}/update_focus_point`, {
			method: "PATCH",
			body: {
				focus_point: {
					[this.fpXKey]: this.fp.x,
					[this.fpYKey]: this.fp.y,
				},
			},
		})
			.then((data) => {
				if (data.error) return showCallout(data.error, "error");

				this.publishFocusPoint();
				if (data.message) showCallout(data.message, "success");
			})
			.catch((_error) => {
				I18n.t("feature.focus_point_editor.update_error").then((text) => {
					showCallout(text, "error");
				});
			});
	}

	calculateOverlayPosition(x, y, fpRect) {
		const overlayRect = this.rects.overlay;

		let overlayLeft = x - overlayRect.width / 2;
		if (overlayLeft < 0) overlayLeft = 0;
		else if (overlayLeft + overlayRect.width > fpRect.width)
			overlayLeft = fpRect.width - overlayRect.width;

		let overlayTop = y - overlayRect.height / 2;
		if (overlayTop < 0) overlayTop = 0;
		else if (overlayTop + overlayRect.height > fpRect.height)
			overlayTop = fpRect.height - overlayRect.height;

		return {
			left: overlayLeft,
			top: overlayTop,
		};
	}

	calculateCrossHairPosition(x, y, fpRect) {
		const chRect = this.rects.crossHair;

		let crossHairLeft = x - chRect.width / 2;
		if (crossHairLeft < 0) crossHairLeft = 0;
		else if (crossHairLeft + chRect.width > fpRect.width)
			crossHairLeft = fpRect.width - chRect.width;

		let crossHairTop = y - chRect.height / 2;
		if (crossHairTop < 0) crossHairTop = 0;
		else if (crossHairTop + chRect.height > fpRect.height)
			crossHairTop = fpRect.height - chRect.height;

		return {
			left: crossHairLeft,
			top: crossHairTop,
		};
	}

	calculateFocusPoint(x, y, fpRect) {
		return {
			x: this.roundFocusPoint(x / fpRect.width),
			y: this.roundFocusPoint(y / fpRect.height),
		};
	}
}
