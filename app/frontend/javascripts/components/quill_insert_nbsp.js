var InsertNbspHandler = function (value) {
  console.log(value);
};

export default InsertNbspHandler;

var toolbarOptions = [
  [{ font: [] }],
  ['bold', 'italic', 'underline'],
  ['blockquote', 'code-block'],
  [{ list: 'ordered' }, { list: 'bullet' }],
  [{ align: [] }],
  ['omega']
];

var quill = new Quill('#editor', {
  modules: {
    toolbar: toolbarOptions
  },
  theme: 'snow'
});

var customButton = document.querySelector('.ql-omega');
customButton.addEventListener('click', function () {
  if (screenfull.enabled) {
    console.log('requesting fullscreen');
    screenfull.request();
  } else {
    console.log('Screenfull not enabled');
  }
});
