// Stay with 1.3.7 for now, SmartBreak and UL/OL are not working in 2.0.0
// switch to another editor if needed
import Quill from "quill";
import Counter from "./../components/quill_counter";
import {
	QuillContentlinkModule,
	ContentlinkBlot,
} from "./../components/quill_content_link";
import {
	QuillLinkFormat,
	QuillLinkModule,
} from "../components/quill_custom_link";
import {
	SmartBreak,
	lineBreakMatcher,
	lineBreakHandler,
} from "../components/quill_smart_break";
import handleEnter from "../components/quill_enter_handler";
import domElementHelpers from "../helpers/dom_element_helpers";
import quillHelpers from "./../helpers/quill_helpers";
import quillCustomHandlers from "../components/quill_custom_handlers";
const icons = Quill.import("ui/icons");
import castArray from "lodash/castArray";
import debounce from "lodash/debounce";

Quill.register(SmartBreak);
Quill.register("modules/contentlink", QuillContentlinkModule);
Quill.register("formats/contentlink", ContentlinkBlot);
Quill.register("modules/customlink", QuillLinkModule);
Quill.register("formats/customlink", QuillLinkFormat);
Quill.register("modules/counter", Counter);

class TextEditor {
	constructor(element) {
		this.element = element;
		this.$container = $(element.parentElement);
		this.editor;
		this.excludeFormats = this.element.dataset.excludeFormats
			? castArray(this.element.dataset.excludeFormats)
			: [];
		this.debouncedUpdate;
		this.availableFormats = {
			none: ["break"],
			minimal: ["bold", "italic", "underline", "break"],
			basic: ["bold", "italic", "header", "underline", "break", "script"],
			full: [
				"bold",
				"italic",
				"header",
				"underline",
				"customlink",
				"blockquote",
				"list",
				"align",
				"break",
				"script",
				"contentlink",
			],
		};
		this.availableToolbarButtons = {
			none: {
				container: [],
			},
			minimal: {
				container: [
					["bold", "italic", "underline"],
					["insertNbsp", "replaceAllNbsp"],
					["clean"],
				],
				handlers: quillCustomHandlers,
			},
			basic: {
				container: [
					[
						{
							header: [1, 2, 3, 4, false],
						},
					],
					[{ script: "sub" }, { script: "super" }],
					["bold", "italic", "underline"],
					["insertNbsp", "replaceAllNbsp"],
					["clean"],
				],
				handlers: quillCustomHandlers,
			},
			full: {
				container: [
					[
						{
							align: [],
						},
					],
					[
						{
							list: "ordered",
						},
						{
							list: "bullet",
						},
					],
					[
						{
							header: [1, 2, 3, 4, false],
						},
					],
					[{ script: "sub" }, { script: "super" }],
					["bold", "italic", "underline", "blockquote"],
					["insertNbsp", "replaceAllNbsp"],
					["customlink", "contentlink"],
					["clean"],
				],
				handlers: quillCustomHandlers,
			},
		};
		this.mode = this.element.dataset.size || "full";
		const toolbarButtons = this.availableToolbarButtons[this.mode];

		if (
			domElementHelpers.parseDataAttribute(this.element.dataset.translateInline)
		)
			toolbarButtons.container.push(["inlineTranslator"]);

		if (domElementHelpers.parseDataAttribute(this.element.dataset.enhanceTips))
			toolbarButtons.container.push(["enhanceTips"]);

		this.options = {
			modules: {
				counter: true,
				contentlink: {},
				customlink: {},
				toolbar: toolbarButtons,
				clipboard: {
					matchers: [["BR", lineBreakMatcher]],
				},
				keyboard: {
					bindings: {
						linebreak: {
							key: 13,
							shiftKey: true,
							handler: lineBreakHandler,
						},
						handleEnter: {
							key: 13,
							handler: handleEnter,
						},
					},
				},
			},
			theme: "snow",
			formats: this.availableFormats[this.mode].filter(
				(v) => !this.excludeFormats.includes(v),
			),
			readOnly: !!this.element.getAttribute("readonly"),
			bounds: this.element,
		};

		if (this.excludeFormats.length) {
			this.options.modules.toolbar.container =
				this.options.modules.toolbar.container.map((v) =>
					v.filter((v) => !this.excludeFormats.includes(v)),
				);
		}

		this.scrollOptions =
			$(".split-content").length > 0
				? {
						$container: $(".split-content.edit-content"),
						condition: (pos, height) => pos < 182 && pos > -height + 230,
						toggleClass: "fixed-split-toolbar",
					}
				: {
						$container: $(window),
						condition: (pos, height) => pos < 55 && pos > -height + 130,
						toggleClass: "fixed-toolbar",
					};

		this.init();
	}
	async init() {
		try {
			await quillCustomHandlers.loadIconsWithTooltips(
				icons,
				this.options.modules.toolbar.container.flat(),
			);

			this.editor = new Quill(this.element, this.options);
			this.removeInitialExtraLines();
			this.addEventHandlers();
		} catch (err) {
			DataCycle.notifications.dispatchEvent(
				new CustomEvent("error", { detail: err }),
			);
		}
	}
	addEventHandlers() {
		this.editor.on("selection-change", this.updateEditorHandler.bind(this));
		this.editor.on(
			"text-change",
			debounce(this.updateSilentHandler.bind(this), 500),
		);

		$(this.editor.container)
			.closest("form")
			.on("reset", this.resetEditor.bind(this));
		$(this.editor.container)
			.on("dc:import:data", this.importData.bind(this))
			.addClass("dc-import-data");
		this.editor.container.addEventListener(
			"reset",
			this.resetEditor.bind(this),
		);
	}
	async importData(event, data) {
		if (this.editor.getText().trim().length > 1 && !data?.force) {
			const target = event.currentTarget;

			domElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => {
					this.editor.clipboard.dangerouslyPasteHTML(data.value);
				},
			);
		} else {
			this.editor.clipboard.dangerouslyPasteHTML(data.value);
		}
	}
	resetEditor(_event) {
		this.editor.clipboard.dangerouslyPasteHTML(
			this.editor.container.dataset.defaultValue || "",
		);
		quillHelpers.updateEditors(this.editor.container, true);
	}
	updateSilentHandler(..._args) {
		quillHelpers.updateEditors(this.editor.container, false);
	}
	updateEditorHandler(range, ..._args) {
		if (range == null) {
			if (this.debouncedUpdate) this.debouncedUpdate.cancel();
			quillHelpers.updateEditors(this.editor.container, true);
		}
	}
	removeInitialExtraLines() {
		const length = this.editor.getLength();
		const text = this.editor.getText(length - 2, 2);

		// Remove extraneous new lines
		if (text === "\n\n") {
			this.editor.deleteText(this.editor.getLength() - 2, 2);
		}
	}
}

export default TextEditor;
