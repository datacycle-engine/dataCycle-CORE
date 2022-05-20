class DragAndDropField {
  constructor(container) {
    this.container = $(container);
    this.uploaderRevealId = this.container.data('asset-uploader');
    this.uploaderReveal = $('#' + this.container.data('asset-uploader'));
    this.fileField = this.container.find('input.content-upload-field');
    this.dragAndDropField = this.container.find('.drag-and-drop-field');

    this.init();
  }
  init() {
    if (!this.isAdvancedUpload) return;
    if (!this.fileField.length) this.fileField = this.uploaderReveal.find('input[type="file"].upload-file');

    this.dragAndDropField
      .on('drag dragstart dragend dragover dragenter dragleave drop', e => {
        e.preventDefault();
        e.stopPropagation();
      })
      .on('dragenter dragover', e => {
        this.dragAndDropField.addClass('is-dragover');
      })
      .on('dragleave dragend drop', e => {
        this.dragAndDropField.removeClass('is-dragover');
      })
      .on('drop', e => {
        this.openUploaderReveal(e.originalEvent.dataTransfer.files);
      })
      .on('click', e => {
        e.preventDefault();
        e.stopPropagation();
        this.fileField.trigger('click');
      });

    this.fileField.on('change', e => {
      e.preventDefault();
      e.stopPropagation();

      this.openUploaderReveal(e.target.files);
    });
  }
  openUploaderReveal(files) {
    $('#' + this.uploaderRevealId)
      .trigger('dc:upload:setFiles', { fileList: files })
      .foundation('open');
  }
  isAdvancedUpload() {
    var div = document.createElement('div');
    return (
      ('draggable' in div || ('ondragstart' in div && 'ondrop' in div)) &&
      'FormData' in window &&
      'FileReader' in window
    );
  }
}

export default DragAndDropField;
