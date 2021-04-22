export default {
  enginePath: '',
  editorSelectors: [
    '> .object-browser',
    '> .embedded-object',
    '> input[type=text]',
    '> .editor-block > .quill-editor',
    '> .v-select > select.multi-select',
    '> .v-select > select.single-select',
    '> .v-select > select.async-select',
    '> ul.classification-checkbox-list',
    '> ul.classification-radiobutton-list',
    '> .form-element > .flatpickr-wrapper > input[type=text].flatpickr-input',
    '> .geographic > .geographic-map',
    '> :checkbox',
    '> :radio',
    '> :input[type="number"]',
    '> .duration-slider > div > input[type="number"]'
  ],
  httpRequest(options = {}) {
    const defaultOptions = {
      headers: {
        'X-CSRF-Token': document.getElementsByName('csrf-token')[0].content
      }
    };

    return $.ajax(_.merge(defaultOptions, options));
  },
  disableElement(element) {
    if (element instanceof $) element = element[0];
    if (element) Rails.disableElement(element);
  },
  enableElement(element) {
    if (element instanceof $) element = element[0];
    if (element) Rails.enableElement(element);
  }
};
