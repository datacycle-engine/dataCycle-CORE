export default {
  insertNbsp: function (_value) {
    var selection = this.quill.getSelection(true);
    this.quill.insertText(selection, '\u00a0');
  },
  replaceAllNbsp: async function (_value) {
    this.quill.disable();

    this.quill.clipboard.dangerouslyPasteHTML(this.quill.root.innerHTML.replaceAll('&nbsp;', ' '));

    const warningContainer = document.createElement('span');
    warningContainer.className = 'quill-notice';
    warningContainer.innerText = await I18n.translate('frontend.text_editor.replaced_all_nbsp');

    this.quill.theme.modules.toolbar.container.querySelector('.ql-replaceAllNbsp').after(warningContainer);

    this.quill.enable();

    setTimeout(() => {
      $(warningContainer).fadeOut('fast', () => {
        warningContainer.remove();
      });
    }, 1000);
  }
};
