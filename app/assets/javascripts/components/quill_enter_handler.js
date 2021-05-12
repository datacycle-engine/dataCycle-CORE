import Quill from 'quill';
const Parchment = Quill.import('parchment');

export default function (range, context) {
  if (range.length > 0) {
    this.quill.scroll.deleteAt(range.index, range.length); // So we do not trigger text-change
  }
  let lineFormats = Object.keys(context.format).reduce(function (lineFormats, format) {
    if (Parchment.query(format, Parchment.Scope.BLOCK) && !Array.isArray(context.format[format])) {
      lineFormats[format] = context.format[format];
    }
    return lineFormats;
  }, {});
  var previousChar = this.quill.getText(range.index - 1, 1);
  // Earlier scroll.deleteAt might have messed up our selection,
  // so insertText's built in selection preservation is not reliable
  this.quill.insertText(range.index, '\n', lineFormats, Quill.sources.USER);
  if (previousChar == '' || previousChar == '\n') {
    this.quill.setSelection(range.index + 2, Quill.sources.SILENT);
  } else {
    this.quill.setSelection(range.index + 1, Quill.sources.SILENT);
  }
  // this.quill.selection.scrollIntoView();
  Object.keys(context.format).forEach(name => {
    if (lineFormats[name] != null) return;
    if (Array.isArray(context.format[name])) return;
    if (name === 'link') return;
    this.quill.format(name, context.format[name], Quill.sources.USER);
  });
}
