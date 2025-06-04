import Quill from "quill";
const QuillModule = Quill.import("core/module");
const InlineBlot = Quill.import("blots/inline");
import { QuillTooltip, Range } from "./quill_tooltip";
const icons = Quill.import("ui/icons");
icons.customlink = icons.link;

class LinkTooltip extends QuillTooltip {
	constructor(quill, bounds) {
		super(quill, bounds);
		this.root.classList.add("dc--customlink-tooltip");
		this.preview = this.root.querySelector("a.ql-preview");
		this.externalCheckbox = this.root.querySelector("input.dc--external-link");
	}

	editLink(event) {
		if (this.root.classList.contains("ql-editing")) {
			this.save();
		} else {
			this.edit("customlink", {
				text: this.preview.textContent,
				external: this.preview.getAttribute("target") === "_blank",
			});
		}
		event.preventDefault();
	}

	removeLink(event) {
		if (this.linkRange != null) {
			const range = this.linkRange;
			this.restoreFocus();
			this.quill.formatText(range, "customlink", false, Quill.sources.USER);
			this.linkRange = null;
		}

		event.preventDefault();

		this.hide();
	}

	changeSelection(range, _oldRange, source) {
		if (range == null) return;
		if (range.length === 0 && source === Quill.sources.USER) {
			const [link, offset] = this.quill.scroll.descendant(
				QuillLinkFormat,
				range.index,
			);
			if (link != null) {
				this.linkRange = new Range(range.index - offset, link.length());
				const preview = QuillLinkFormat.formats(link.domNode);
				this.preview.textContent = preview?.text;
				this.preview.setAttribute("href", this.preview.textContent);
				if (preview?.external) this.preview.setAttribute("target", "_blank");
				else this.preview.removeAttribute("target");

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

	edit(mode = "link", preview = null) {
		this.root.classList.remove("ql-hidden");
		this.root.classList.add("ql-editing");
		this.externalCheckbox.disabled = false;

		if (preview?.text) {
			this.textbox.value = preview.text;
			this.externalCheckbox.checked = preview.external;
		} else if (mode !== this.root.getAttribute("data-mode")) {
			this.textbox.value = "";
			this.externalCheckbox.checked = true;
		}

		this.position(this.quill.getBounds(this.quill.selection.savedRange));
		this.textbox.select();
		this.textbox.setAttribute(
			"placeholder",
			this.textbox.getAttribute(`data-${mode}`) || "",
		);
		this.root.setAttribute("data-mode", mode);
	}

	show() {
		super.show();
		this.externalCheckbox.checked =
			this.preview.getAttribute("target") === "_blank";
		this.externalCheckbox.disabled = true;
		this.root.removeAttribute("data-mode");
	}

	save() {
		let { value } = this.textbox;
		value = {
			text: value,
			external: this.externalCheckbox?.checked,
		};

		switch (this.root.getAttribute("data-mode")) {
			case "customlink": {
				const { scrollTop } = this.quill.root;

				if (this.linkRange) {
					this.quill.formatText(
						this.linkRange,
						"customlink",
						value,
						Quill.sources.USER,
					);
					this.linkRange = null;
				} else {
					this.restoreFocus();
					this.quill.format("customlink", value, Quill.sources.USER);
				}

				this.quill.root.scrollTop = scrollTop;
				break;
			}
			default:
		}

		this.textbox.value = "";
		this.externalCheckbox.checked = true;
		this.externalCheckbox.disabled = true;
		this.hide();
	}
}

LinkTooltip.TEMPLATE = [
	'<a class="ql-preview" rel="noopener noreferrer" href="about:blank"></a>',
	'<input type="text" data-formula="e=mc^2" data-link="https://quilljs.com" data-video="Embed URL">',
	'<a class="ql-action"></a>',
	'<a class="ql-remove"></a>',
	'<br><label class="dc--external-link-label"><input disabled="disabled" type="checkbox" checked="checked" class="dc--external-link"><span class="dc--external-link-text">In neuem Tab öffnen</span></label>',
].join("");

class QuillLinkFormat extends InlineBlot {
	static create(value) {
		// biome-ignore lint/complexity/noThisInStatic: <explanation>
		const node = super.create(value);
		node.setAttribute("href", QuillLinkFormat.sanitize(value?.text));
		node.setAttribute("rel", "noopener noreferrer");
		if (value?.external) node.setAttribute("target", "_blank");
		return node;
	}

	static formats(domNode) {
		return {
			text: domNode.getAttribute("href"),
			external: domNode.getAttribute("target") === "_blank",
		};
	}

	static sanitize(url) {
		return sanitize(url, QuillLinkFormat.PROTOCOL_WHITELIST)
			? url
			: QuillLinkFormat.SANITIZED_URL;
	}

	format(name, value) {
		if (name !== this.statics.blotName || !value || !value.text) {
			super.format(name, value);
		} else {
			this.domNode.setAttribute("href", this.constructor.sanitize(value.text));
			if (value.external) this.domNode.setAttribute("target", "_blank");
			else this.domNode.removeAttribute("target");
		}
	}
}
QuillLinkFormat.blotName = "customlink";
QuillLinkFormat.tagName = "a";
QuillLinkFormat.SANITIZED_URL = "about:blank";
QuillLinkFormat.PROTOCOL_WHITELIST = ["http", "https", "mailto", "tel"];

function sanitize(url, protocols) {
	const anchor = document.createElement("a");
	anchor.href = url;
	const protocol = anchor.href.slice(0, anchor.href.indexOf(":"));
	return protocols.indexOf(protocol) > -1;
}

class QuillLinkModule extends QuillModule {
	constructor(quill, options) {
		super(quill.container, options);
		this.quill = quill;
		this.tooltip = new LinkTooltip(this.quill, quill.options.bounds);
		this.quill
			.getModule("toolbar")
			.addHandler("customlink", this.customlinkHandler.bind(this));
	}
	customlinkHandler(value) {
		if (value) {
			const range = this.quill.getSelection();
			if (range == null || range.length === 0) return;
			const preview = this.quill.getText(range);
			this.tooltip.edit("customlink", {
				text: preview,
				external: true,
			});
		} else {
			this.quill.format("customlink", false);
		}
	}
}

export { QuillLinkFormat, QuillLinkModule };
