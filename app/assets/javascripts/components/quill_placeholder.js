import Quill from "quill";

const QuillModule = Quill.import("core/module");
const InlineBlot = Quill.import("blots/inline");

import { QuillTooltip, Range } from "./quill_tooltip";

const icons = Quill.import("ui/icons");
icons.placeholder =
	'<span data-dc-tooltip="Platzhalter"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M9 4H7a3 3 0 0 0-3 3v2h2V7a1 1 0 0 1 1-1h2V4Zm6 0h2a3 3 0 0 1 3 3v2h-2V7a1 1 0 0 0-1-1h-2V4ZM9 20H7a3 3 0 0 1-3-3v-2h2v2a1 1 0 0 0 1 1h2v2Zm6 0h2a3 3 0 0 0 3-3v-2h-2v2a1 1 0 0 1-1 1h-2v2Z"/></svg></span>';

class PlaceholderTooltip extends QuillTooltip {
	constructor(quill, bounds) {
		super(quill, bounds);
		this.root.classList.add("dc--placeholder-tooltip");
		this.preview = this.root.querySelector("span.ql-preview");
		this.label = this.root.querySelector(".dc--placeholder-tooltip-label");
		this.loadLabel();
	}

	async loadLabel() {
		const text = await I18n.translate("frontend.text_editor.placeholder_label");
		if (text) this.label.textContent = `${text}:`;
	}

	editLink(event) {
		if (this.root.classList.contains("ql-editing")) {
			this.save();
		} else {
			this.edit("placeholder", this.preview.textContent);
		}
		event.preventDefault();
	}

	removeLink(event) {
		if (this.linkRange != null) {
			const range = this.linkRange;
			this.restoreFocus();
			this.quill.formatText(range, "placeholder", false, Quill.sources.USER);
			this.linkRange = null;
		}

		event.preventDefault();
		this.hide();
	}

	changeSelection(range, _oldRange, source) {
		if (range == null) return;
		if (range.length === 0 && source === Quill.sources.USER) {
			const [link, offset] = this.quill.scroll.descendant(
				QuillPlaceholderFormat,
				range.index,
			);
			if (link != null) {
				this.linkRange = new Range(range.index - offset, link.length());
				const preview = QuillPlaceholderFormat.formats(link.domNode);
				this.preview.textContent = preview;

				this.show();
				this.position(this.quill.getBounds(this.linkRange));
				return;
			}
		} else {
			this.linkRange = null;
		}
		this.hide();
	}

	listen() {
		super.listen();

		this.root
			.querySelector("a.ql-action")
			.addEventListener("click", this.editLink.bind(this));

		this.root
			.querySelector("a.ql-remove")
			.addEventListener("click", this.removeLink.bind(this));

		this.quill.on(
			Quill.events.SELECTION_CHANGE,
			this.changeSelection.bind(this),
		);
	}

	show() {
		super.show();
		this.root.removeAttribute("data-mode");
	}

	save() {
		const value = this.textbox.value.trim();

		if (this.root.getAttribute("data-mode") === "placeholder") {
			if (!value) {
				this.textbox.value = "";
				this.hide();
				return;
			}

			const { scrollTop } = this.quill.root;

			if (this.linkRange) {
				this.quill.formatText(
					this.linkRange,
					"placeholder",
					value,
					Quill.sources.USER,
				);
				this.linkRange = null;
			} else {
				this.restoreFocus();
				this.quill.format("placeholder", value, Quill.sources.USER);
			}

			this.quill.root.scrollTop = scrollTop;
		}

		this.textbox.value = "";
		this.hide();
	}
}

PlaceholderTooltip.TEMPLATE = [
	'<span class="dc--placeholder-tooltip-label">Platzhalter:</span>',
	'<span class="ql-preview"></span>',
	'<input type="text" data-placeholder="placeholder-key">',
	'<a class="ql-action"></a>',
	'<a class="ql-remove"></a>',
].join("");

class QuillPlaceholderFormat extends InlineBlot {
	static create(value) {
		// biome-ignore lint/complexity/noThisInStatic: Parchment's create() reads this.className/tagName from the subclass
		const node = super.create(value);
		node.setAttribute("data-dc-placeholder", value);
		return node;
	}

	static formats(domNode) {
		return domNode.getAttribute("data-dc-placeholder");
	}

	format(name, value) {
		if (name !== this.statics.blotName || !value) {
			super.format(name, value);
		} else {
			this.domNode.setAttribute("data-dc-placeholder", value);
		}
	}
}
QuillPlaceholderFormat.blotName = "placeholder";
QuillPlaceholderFormat.tagName = "span";
QuillPlaceholderFormat.className = "dc--placeholder";

class QuillPlaceholderModule extends QuillModule {
	constructor(quill, options) {
		super(quill.container, options);
		this.quill = quill;
		this.tooltip = new PlaceholderTooltip(this.quill, quill.options.bounds);
		this.quill
			.getModule("toolbar")
			.addHandler("placeholder", this.placeholderHandler.bind(this));
	}
	placeholderHandler(value) {
		if (value) {
			const range = this.quill.getSelection();
			if (range == null || range.length === 0) return;
			const preview = this.quill.getText(range);
			this.tooltip.edit("placeholder", preview);
		} else {
			this.quill.format("placeholder", false);
		}
	}
}

export { QuillPlaceholderFormat, QuillPlaceholderModule };
