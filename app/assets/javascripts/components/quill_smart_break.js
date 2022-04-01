import Quill from 'quill';
const Break = Quill.import('blots/break');
const Embed = Quill.import('blots/embed');
const Delta = Quill.import('delta');

class SmartBreak extends Break {
  length() {
    return 1;
  }
  value() {
    return '\n';
  }
  insertInto(parent, ref) {
    Embed.prototype.insertInto.call(this, parent, ref);
  }
}

SmartBreak.blotName = 'break';
SmartBreak.tagName = 'BR';

function lineBreakMatcher() {
  var newDelta = new Delta();
  newDelta.insert({ break: '' });
  return newDelta;
}

function lineBreakHandler(range) {
  let currentLeaf = this.quill.getLeaf(range.index)[0];
  let nextLeaf = this.quill.getLeaf(range.index + 1)[0];

  this.quill.insertEmbed(range.index, 'break', true, 'user');

  // Insert a second break if:
  // At the end of the editor, OR next leaf has a different parent (<p>)
  if (nextLeaf === null || currentLeaf.parent !== nextLeaf.parent) {
    this.quill.insertEmbed(range.index, 'break', true, 'user');
  }

  // Now that we've inserted a line break, move the cursor forward
  this.quill.setSelection(range.index + 1, Quill.sources.SILENT);
}

export { SmartBreak, lineBreakMatcher, lineBreakHandler };
