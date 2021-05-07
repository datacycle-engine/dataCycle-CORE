import Quill from 'quill';
const QuillModule = Quill.import('core/module');
const InlineBlot = Quill.import('blots/inline');
import { QuillTooltip, Range } from './quill_tooltip';
const icons = Quill.import('ui/icons');
icons['contentlink'] =
  '<span title="dataCycle-Referenz"><svg xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cc="http://creativecommons.org/ns#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xml:space="preserve" viewBox="0 0 90 90" id="Ebene_1" version="1.1"><defs id="defs105" /><g transform="translate(-14.186671,-14.2)" id="g88"><g id="g86"><g id="g82"><g id="g72"><rect id="rect70" height="21.700001" width="21.700001" class="st0" transform="matrix(0.7071,-0.7071,0.7071,0.7071,-26.5971,48.1504)" y="45.299999" x="34"/></g><g id="g76"><rect id="rect74" height="21.700001" width="21.700001" class="st1" transform="matrix(0.7071,-0.7071,0.7071,0.7071,-20.2491,32.8249)" y="30" x="18.700001"/></g><g id="g80"><rect id="rect78" height="21.700001" width="21.700001" transform="matrix(0.7071,-0.7071,0.7071,0.7071,-41.9226,41.8024)" y="60.700001" x="18.700001"/></g></g><path id="path84" d="M 100.2,54.7 C 99.4,32 80.7,14.2 58.2,14.2 c -0.5,0 -1,0 -1.5,0 -10.6,0.4 -20.1,4.7 -27.2,11.4 l 15.3,15.3 c 0,0 4.7,-5 12.7,-5 0.3,0 0.5,0 0.8,0 v 0 c 11,0 20,8.6 20.4,19.7 0.4,11.2 -8.4,20.7 -19.7,21.1 -0.3,0 -0.5,0 -0.8,0 -5.2,0 -9.9,-1.9 -13.5,-5.1 L 29.5,86.8 c 7.5,7.1 17.7,11.4 28.7,11.4 0.5,0 1,0 1.5,0 23.2,-0.9 41.4,-20.4 40.5,-43.5 z" class="st3"/></g></g></svg></span>';

class ContentLinkTooltip extends QuillTooltip {
  constructor(quill, bounds) {
    super(quill, bounds);
    this.root.classList.add('dc--contentlink-tooltip');
    this.preview = this.root.querySelector('span.ql-preview');
  }

  listen() {
    super.listen();
    this.root.querySelector('a.ql-action').addEventListener('click', event => {
      if (this.root.classList.contains('ql-editing')) {
        this.save();
      } else {
        this.edit('contentlink', this.preview.textContent);
      }
      event.preventDefault();
    });
    this.root.querySelector('a.ql-remove').addEventListener('click', event => {
      if (this.linkRange != null) {
        const range = this.linkRange;
        this.restoreFocus();
        this.quill.formatText(range, 'contentlink', false, Quill.sources.USER);
        delete this.linkRange;
      }
      event.preventDefault();
      this.hide();
    });
    this.quill.on(Quill.events.SELECTION_CHANGE, (range, oldRange, source) => {
      if (range == null) return;
      if (range.length === 0 && source === Quill.sources.USER) {
        const [link, offset] = this.quill.scroll.descendant(ContentlinkBlot, range.index);

        if (link != null) {
          this.linkRange = new Range(range.index - offset, link.length());
          const preview = ContentlinkBlot.formats(link.domNode);
          this.preview.textContent = preview;
          this.preview.setAttribute('data-href', preview);
          this.preview.setAttribute('title', 'dataCycle: ' + preview);
          this.show();
          this.position(this.quill.getBounds(this.linkRange));
          return;
        }
      } else {
        delete this.linkRange;
      }
      this.hide();
    });
  }

  show() {
    super.show();
    this.root.removeAttribute('data-mode');
  }

  save() {
    let { value } = this.textbox;
    switch (this.root.getAttribute('data-mode')) {
      case 'contentlink': {
        const { scrollTop } = this.quill.root;
        if (this.linkRange) {
          this.quill.formatText(this.linkRange, 'contentlink', value, Quill.sources.USER);
          delete this.linkRange;
        } else {
          this.restoreFocus();
          this.quill.format('contentlink', value, Quill.sources.USER);
        }
        this.quill.root.scrollTop = scrollTop;
        break;
      }
      default:
    }
    this.textbox.value = '';
    this.hide();
  }
}

ContentLinkTooltip.TEMPLATE = [
  '<span class="ql-preview"></span>',
  '<input type="text">',
  '<a class="ql-action"></a>',
  '<a class="ql-remove"></a>'
].join('');

class ContentlinkBlot extends InlineBlot {
  static create(value) {
    let node = super.create();
    node.setAttribute('data-href', value);
    node.setAttribute('title', 'dataCycle: ' + value);
    return node;
  }
  static formats(node) {
    return node.getAttribute('data-href');
  }
  format(name, value) {
    if (name !== this.statics.blotName || !value) {
      super.format(name, value);
    } else {
      this.domNode.setAttribute('data-href', value);
      this.domNode.setAttribute('title', 'dataCycle: ' + value);
    }
  }
}
ContentlinkBlot.blotName = 'contentlink';
ContentlinkBlot.className = 'dc--contentlink';
ContentlinkBlot.tagName = 'span';

class QuillContentlinkModule extends QuillModule {
  constructor(quill, options) {
    super(quill.container, options);
    this.quill = quill;
    this.tooltip = new ContentLinkTooltip(this.quill, quill.options.bounds);
    this.quill.getModule('toolbar').addHandler('contentlink', this.contentlinkHandler.bind(this));
  }
  contentlinkHandler(value) {
    if (value) {
      const range = this.quill.getSelection();
      if (range == null || range.length === 0) return;
      let preview = this.quill.getText(range);
      this.tooltip.edit('contentlink', preview);
    } else {
      this.quill.format('contentlink', false);
    }
  }
}

export { QuillContentlinkModule, ContentlinkBlot, ContentLinkTooltip };
