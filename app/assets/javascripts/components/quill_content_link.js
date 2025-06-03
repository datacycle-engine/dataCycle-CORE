import Quill from "quill";
const QuillModule = Quill.import("core/module");
const InlineBlot = Quill.import("blots/inline");
import { QuillTooltip, Range } from "./quill_tooltip";
const icons = Quill.import("ui/icons");
icons.contentlink =
	'<span data-dc-tooltip="dataCycle-Referenz"><svg id="Ebene_1" viewBox="0 0 118.46 76.680002" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg"><path class="cls-1" d="m 91.35,11.23 v 0 c -7.48,0 -14.26,3.03 -19.17,7.94 l 7.19,7.19 c 3.07,-3.07 7.3,-4.96 11.98,-4.96 9.36,0 16.94,7.59 16.94,16.94 0,9.35 -7.58,16.94 -16.94,16.94 -4.68,0 -8.92,-1.9 -11.98,-4.96 l -7.19,7.19 c 4.91,4.9 11.68,7.94 19.17,7.94 14.97,0 27.11,-12.14 27.11,-27.11 0,-14.97 -12.14,-27.11 -27.11,-27.11" id="path1" /><path class="cls-1" d="M 14.38,38.34 38.34,14.38 62.3,38.34 38.34,62.3 Z M 38.34,0 0,38.34 38.34,76.68 76.68,38.34 Z" id="path2" /></svg></span>';
import { nanoid } from "nanoid";

class ContentLinkTooltip extends QuillTooltip {
	constructor(quill, bounds) {
		super(quill, bounds);

		this.container = quill.container;
		this.key = "linked_in_text_dummy";
		this.root.classList.add("dc--contentlink-tooltip");
		this.preview = this.root.querySelector("div.ql-preview");
		this.isNew = false;
		this.contentTemplate = this.container.dataset.template;
		this.contentId = this.container.dataset.contentId;
		this.contentTemplateName = this.container.dataset.contentTemplateName;
	}

	renderSelectedValue(value, options, definition) {
		let selectedIds = "";
		if (value) {
			const params = {
				key: this.key,
				definition: definition,
				content: null,
				parameters: {
					object: { id: value, class: "DataCycleCore::Thing" },
					options: options,
					editable: false,
					edit_buttons: true,
				},
			};
			selectedIds += `<li class="item remote-render" data-id="${value}" data-remote-render-function="render_linked_partial" data-remote-strategy="replaceSelf" data-remote-render-params='${JSON.stringify(params)}'><input type="hidden" name="${this.key}[]" value="${value}"></li>`;
		}

		return selectedIds;
	}

	renderObjectBrowserHtml(value, editorId, initialState = "closed") {
		const definition = {
			type: "linked",
		};
		const options = {
			html_id: this.key,
			content: null,
			key: this.key,
			definition: definition,
		};

		return `<div class="object-browser"
               id="${editorId}"
               data-hidden-field-id="${editorId}_default"
               data-definition='${JSON.stringify(definition)}'
               data-max="1"
               data-objects='${JSON.stringify(value ? [value] : [])}'
               data-template-name="${this.contentTemplateName}"
               data-template='${this.contentTemplate}'
               data-content-id="${this.contentId}"
               data-key="${this.key}">
            <div class="media-thumbs">
              <ul class="object-thumbs no-bullet">
                <input type="hidden" name="${this.key}[]" value="">
                ${this.renderSelectedValue(value, options, definition)}
              </ul>
            </div>
          </div>
          <div class="object-browser-overlay full reveal without-overlay remote-render"
              id="object_browser_${editorId}"
              data-overlay="false"
              data-reveal
              data-v-offset="0"
              data-multiple-opened="true"
              data-initial-state="${initialState}"
              data-remote-path="data_cycle_core/object_browser/editor_overlay"
              data-remote-options='${JSON.stringify(options)}'></div>
          <button class="button show-objectbrowser" data-disable id="show-object-browser-${editorId}" type="button" data-open="object_browser_${editorId}"></button>`;
	}

	renderObjectBrowser(value, initialState = "closed") {
		const editorId = nanoid();
		const overlayId = `object_browser_${editorId}`;
		const containerId = `object_browser_container_${editorId}`;
		this.preview.innerHTML = this.renderObjectBrowserHtml(
			value,
			editorId,
			initialState,
		);
		this.objectBrowserContainer = document.getElementById(containerId);
		this.objectBrowser = document.getElementById(editorId);
		this.objectBrowserOverlay = document.getElementById(overlayId);
		$(this.objectBrowser).on("dc:objectBrowser:change", this.save.bind(this));
		$(this.objectBrowserOverlay).on(
			"closed.zf.reveal",
			this.closeObjectBrowser.bind(this),
		);
	}

	removeLink(event) {
		if (this.linkRange != null) {
			const range = this.linkRange;
			this.restoreFocus();
			this.quill.formatText(range, "contentlink", false, Quill.sources.USER);
			this.linkRange = null;
		}

		event.preventDefault();
		this.hide();
	}

	editLink(event) {
		this.edit("contentlink", this.preview.textContent);

		event.preventDefault();
	}

	changeSelection(range, _oldRange, source) {
		if (range == null) return;
		if (range.length === 0 && source === Quill.sources.USER) {
			const [link, offset] = this.quill.scroll.descendant(
				ContentlinkBlot,
				range.index,
			);

			if (link != null) {
				this.linkRange = new Range(range.index - offset, link.length());
				const preview = ContentlinkBlot.formats(link.domNode);

				this.renderObjectBrowser(preview);
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

	edit(_mode, _preview) {
		if (this.objectBrowserOverlay)
			$(this.objectBrowserOverlay).foundation("open");
	}

	closeObjectBrowser(_event) {
		if (this.isNew) this.hide();
	}

	hide() {
		if (this.preview) {
			this.preview.innerHTML = "";
		}

		this.isNew = false;

		super.hide();
	}

	save(event, data) {
		const value = data?.ids?.[0];

		if (!value) return this.removeLink(event);

		const { scrollTop } = this.quill.root;
		if (this.linkRange) {
			this.quill.formatText(
				this.linkRange,
				"contentlink",
				value,
				Quill.sources.USER,
			);
			this.linkRange = null;
		} else {
			this.restoreFocus();
			this.quill.format("contentlink", value, Quill.sources.USER);
		}
		this.quill.root.scrollTop = scrollTop;
		this.hide();
	}
}

ContentLinkTooltip.TEMPLATE = [
	"<h6>dataCycle-Referenz:</h6>",
	'<div class="ql-preview"></div>',
	'<input type="text">',
	'<a class="ql-action"></a>',
	'<a class="ql-remove"></a>',
].join("");

class ContentlinkBlot extends InlineBlot {
	static create(value) {
		// biome-ignore lint/complexity/noThisInStatic: <explanation>
		const node = super.create();
		node.dataset.href = value;
		node.dataset.dcTooltip = `dataCycle: ${value}`;
		return node;
	}
	static formats(node) {
		return node.dataset.href;
	}
	format(name, value) {
		if (name !== this.statics.blotName || !value) {
			super.format(name, value);
		} else {
			this.domNode.dataset.href = value;
			this.domNode.dataset.dcTooltip = `dataCycle: ${value}`;
		}
	}
}
ContentlinkBlot.blotName = "contentlink";
ContentlinkBlot.className = "dc--contentlink";
ContentlinkBlot.tagName = "span";

class QuillContentlinkModule extends QuillModule {
	constructor(quill, options) {
		super(quill.container, options);
		this.quill = quill;
		this.tooltip = new ContentLinkTooltip(this.quill, quill.options.bounds);
		this.quill
			.getModule("toolbar")
			.addHandler("contentlink", this.contentlinkHandler.bind(this));
	}
	contentlinkHandler(value) {
		if (value) {
			const range = this.quill.getSelection();
			if (range == null || range.length === 0) return;
			this.tooltip.isNew = true;
			this.tooltip.renderObjectBrowser(null, "open");
		} else {
			this.quill.format("contentlink", false);
		}
	}
}

export { QuillContentlinkModule, ContentlinkBlot, ContentLinkTooltip };
