import Quill from "quill";
const QuillModule = Quill.import("core/module");
const InlineBlot = Quill.import("blots/inline");
import { QuillTooltip, Range } from "./quill_tooltip";
const icons = Quill.import("ui/icons");
icons.contentlink =
	'<span data-dc-tooltip="dataCycle-Referenz"><svg xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cc="http://creativecommons.org/ns#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xml:space="preserve" viewBox="0 0 90 90" id="Ebene_1" version="1.1"><defs id="defs105" /><g transform="translate(-14.186671,-14.2)" id="g88"><g id="g86"><g id="g82"><g id="g72"><rect id="rect70" height="21.700001" width="21.700001" class="st0" transform="matrix(0.7071,-0.7071,0.7071,0.7071,-26.5971,48.1504)" y="45.299999" x="34"/></g><g id="g76"><rect id="rect74" height="21.700001" width="21.700001" class="st1" transform="matrix(0.7071,-0.7071,0.7071,0.7071,-20.2491,32.8249)" y="30" x="18.700001"/></g><g id="g80"><rect id="rect78" height="21.700001" width="21.700001" transform="matrix(0.7071,-0.7071,0.7071,0.7071,-41.9226,41.8024)" y="60.700001" x="18.700001"/></g></g><path id="path84" d="M 100.2,54.7 C 99.4,32 80.7,14.2 58.2,14.2 c -0.5,0 -1,0 -1.5,0 -10.6,0.4 -20.1,4.7 -27.2,11.4 l 15.3,15.3 c 0,0 4.7,-5 12.7,-5 0.3,0 0.5,0 0.8,0 v 0 c 11,0 20,8.6 20.4,19.7 0.4,11.2 -8.4,20.7 -19.7,21.1 -0.3,0 -0.5,0 -0.8,0 -5.2,0 -9.9,-1.9 -13.5,-5.1 L 29.5,86.8 c 7.5,7.1 17.7,11.4 28.7,11.4 0.5,0 1,0 1.5,0 23.2,-0.9 41.4,-20.4 40.5,-43.5 z" class="st3"/></g></g></svg></span>';
import { nanoid } from "nanoid";

class ContentLinkTooltip extends QuillTooltip {
	constructor(quill, bounds) {
		super(quill, bounds);

		this.container = quill.container;
		this.key = "linked_in_text_dummy";
		this.root.classList.add("dc--contentlink-tooltip");
		this.preview = this.root.querySelector("span.ql-preview");

		console.log("create ContentLinkTooltip");
	}

	renderSelectedValue(value, options) {
		let selectedIds = "";
		if (value) {
			const params = {
				key: this.key,
				definition: options.definition,
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

	renderObjectBrowserHtml(value, containerId) {
		const options = {
			html_id: this.key,
			content: null,
			key: this.key,
			definition: {
				type: "linked",
			},
		};

		return `<div class="object-browser-container form-element validation-container" id="${containerId}">
          <div class="object-browser"
               id="${this.editorId}"
               data-hidden-field-id="${this.editorId}_default"
               data-definition='${JSON.stringify(options)}'
               data-min="1"
               data-max="1"
               data-objects='${JSON.stringify(value ? [value] : [])}'
               data-key="${this.key}">
            <div class="media-thumbs">
              <ul class="object-thumbs no-bullet">
                <input type="hidden" name="${this.key}[]" value="">
                ${this.renderSelectedValue(value, options)}
              </ul>
            </div>
          </div>
          <div class="object-browser-overlay full reveal without-overlay remote-render"
              id="object_browser_${this.editorId}"
              data-overlay="false"
              data-reveal
              data-v-offset="0"
              data-multiple-opened="true"
              data-initial-state="open"
              data-remote-path="data_cycle_core/object_browser/editor_overlay"
              data-remote-options='${JSON.stringify(options)}'></div>
        </div>`;
	}

	renderObjectBrowser(value) {
		const overlayId = `object_browser_${this.editorId}`;
		this.objectBrowser = document.getElementById(this.editorId);
		this.objectBrowserOverlay = document.getElementById(overlayId);
		const containerId = `object_browser_container_${this.editorId}`;
		this.objectBrowserContainer = document.getElementById(containerId);

		if (!this.objectBrowserContainer) {
			this.container.insertAdjacentHTML(
				"beforeend",
				this.renderObjectBrowserHtml(value, containerId),
			);
			this.objectBrowserContainer = document.getElementById(containerId);
			this.objectBrowser = document.getElementById(this.editorId);
			this.objectBrowserOverlay = document.getElementById(overlayId);
			$(this.objectBrowser).on("dc:objectBrowser:change", this.save.bind(this));
		} else {
			$(this.objectBrowserOverlay).foundation("open");
		}
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
		console.log(
			"editLink",
			this.preview.dataset.editorId,
			this.preview.textContent,
		);
		this.editorId = this.preview.dataset.editorId || nanoid();
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
				console.log("changeSelection", link, preview.editorId);

				this.preview.textContent = preview.id;
				this.preview.dataset.href = preview.id;
				this.preview.dataset.editorId = preview.editorId
					? preview.editorId
					: "";
				this.preview.dataset.dcTooltip = `dataCycle: ${preview.id}`;
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

		console.log("listen ContentLinkTooltip", this.editorId);

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
		console.log("show", this.editorId, this.textbox.value);
		super.show();

		this.root.removeAttribute("data-mode");
	}

	edit(mode, preview) {
		console.log("edit mode", this.editorId);
		this.renderObjectBrowser(preview);
		this.preview.dataset.editorId = this.editorId;

		console.log("edit", this.editorId, mode, preview);
	}

	hide() {
		console.log("hide", this.editorId);
		this.editorId = null;

		if (this.preview) {
			console.log("hide preview", this.preview);
			this.preview.textContent = "";
			this.preview.dataset.href = "";
			this.preview.dataset.editorId = "";
			this.preview.dataset.dcTooltip = "";
		}

		super.hide();
	}

	save(event, data) {
		console.log("save", this.editorId, event, data);
		const value = {
			id: data?.ids?.[0],
			editorId: this.editorId,
		};

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

		this.textbox.value = "";
		this.hide();
	}
}

ContentLinkTooltip.TEMPLATE = [
	'<span class="ql-preview"></span>',
	'<input type="text">',
	'<a class="ql-action"></a>',
	'<a class="ql-remove"></a>',
].join("");

class ContentlinkBlot extends InlineBlot {
	static create(value) {
		console.log("create contentlink", value);
		const id = value?.id || value;
		// biome-ignore lint/complexity/noThisInStatic: <explanation>
		const node = super.create();
		node.dataset.href = id;
		node.dataset.editorId = value?.editorId ? value?.editorId : "";
		node.dataset.dcTooltip = `dataCycle: ${id}`;
		return node;
	}
	static formats(node) {
		return {
			id: node.dataset.href,
			editorId: node.dataset.editorId,
		};
	}
	format(name, value) {
		console.log("format contentlink", name, value);
		const id = value?.id || value;

		if (name !== this.statics.blotName || !id) {
			super.format(name, id);
		} else {
			this.domNode.dataset.href = id;
			this.domNode.dataset.editorId = value?.editorId ? value?.editorId : "";
			this.domNode.dataset.dcTooltip = `dataCycle: ${id}`;
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
			const preview = this.quill.getText(range);
			console.log("contentlinkHandler", preview, range);
			this.tooltip.editorId = nanoid();
			this.tooltip.edit("contentlink", null);
		} else {
			this.quill.format("contentlink", false);
		}
	}
}

export { QuillContentlinkModule, ContentlinkBlot, ContentLinkTooltip };
