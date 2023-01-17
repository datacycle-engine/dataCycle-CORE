const TuiImageEditor = () => import('tui-image-editor').then(mod => mod.default);
import CalloutHelpers from './../helpers/callout_helpers';

class ImageEditor {
  constructor(reveal) {
    reveal.classList.add('dcjs-image-editor');
    this.supportedFileExtensions = ['jpg', 'jpeg', 'png'];
    this.$reveal = $(reveal);
    this.editor = null;
    this.fileUrl = reveal.dataset.fileUrl;
    this.fileName = reveal.dataset.fileName || 'unnamed_asset';
    this.fileMimeType = reveal.dataset.fileMimeType;
    this.assetId = reveal.dataset.assetId;
    this.hiddenFieldKey = reveal.dataset.hiddenFieldKey;
    this.saveButton = this.$reveal.find('.save-button');
    this.editableList = $(`[data-image-editor="${this.$reveal.prop('id')}"]`)
      .closest('.form-element.asset')
      .find('> .asset-list')
      .first();
    this.outerEditButton = $(`[data-image-editor="${this.$reveal.prop('id')}"]`)
      .find('.image-editor-button')
      .first();
    this.fileFormat = this.setFileFormat(this.fileMimeType);

    if (!this.assetId) this.initFile();

    this.initEvents();
    this.setup();
  }
  initEvents() {
    this.saveButton.on('click', this.handleSave.bind(this));
    this.editableList.on('dc:asset_list:changed', this.handleAssetChange.bind(this));
  }
  handleAssetChange(_event, data) {
    const newAsset = data.assets[0];
    this.fileUrl = newAsset.file.url;
    if (newAsset.name.split('.').length > 1) {
      this.fileName = newAsset.name.split('.').slice(0, -1).join('.');
    } else {
      this.fileName = newAsset.name;
    }
    this.fileMimeType = newAsset.content_type;
    this.fileFormat = this.setFileFormat(this.fileMimeType);
    this.setup();
  }
  setFileFormat(mimeType) {
    const fileFormatArr = mimeType.split('/');
    const fileFormat = fileFormatArr[fileFormatArr.length - 1];

    this.updateOuterEditButton(this.supportedFileExtensions.includes(fileFormat)).then(r => {});
    return fileFormat === 'jpeg' || fileFormat === 'jpg' ? 'jpeg' : 'png';
  }
  async updateOuterEditButton(supported = false) {
    if (supported) {
      this.outerEditButton.removeClass('warning');
      this.outerEditButton.attr('title', await I18n.translate('frontend.image_editor.edit_image'));
    } else {
      this.outerEditButton.addClass('warning');
      this.outerEditButton.attr('title', await I18n.translate('frontend.image_editor.unsupported_format'));
    }
  }
  setup() {
    // @todo: move to config
    const blackTheme = {
      'common.bi.image': '',
      'common.bisize.width': '251px',
      'common.bisize.height': '21px',
      'common.backgroundImage': 'none',
      'common.backgroundColor': '#1e1e1e',
      'common.border': '0px',

      // header
      'header.backgroundImage': 'none',
      'header.backgroundColor': 'transparent',
      'header.border': '0px',

      // load button
      'loadButton.backgroundColor': '#fff',
      'loadButton.border': '1px solid #ddd',
      'loadButton.color': '#222',
      'loadButton.fontFamily': "'Noto Sans', sans-serif",
      'loadButton.fontSize': '12px',

      // download button
      'downloadButton.backgroundColor': '#fdba3b',
      'downloadButton.border': '1px solid #fdba3b',
      'downloadButton.color': '#fff',
      'downloadButton.fontFamily': "'Noto Sans', sans-serif",
      'downloadButton.fontSize': '12px',

      // main icons
      'menu.normalIcon.color': '#8a8a8a',
      'menu.activeIcon.color': '#555555',
      'menu.disabledIcon.color': '#434343',
      'menu.hoverIcon.color': '#e9e9e9',
      'menu.iconSize.width': '24px',
      'menu.iconSize.height': '24px',

      // submenu icons
      'submenu.normalIcon.color': '#8a8a8a',
      'submenu.activeIcon.color': '#e9e9e9',
      'submenu.iconSize.width': '32px',
      'submenu.iconSize.height': '32px',

      // submenu primary color
      'submenu.backgroundColor': '#1e1e1e',
      'submenu.partition.color': '#3c3c3c',

      // submenu labels
      'submenu.normalLabel.color': '#8a8a8a',
      'submenu.normalLabel.fontWeight': 'lighter',
      'submenu.activeLabel.color': '#fff',
      'submenu.activeLabel.fontWeight': 'lighter',

      // checkbox style
      'checkbox.border': '0px',
      'checkbox.backgroundColor': '#fff',

      // range style
      'range.pointer.color': '#fff',
      'range.bar.color': '#666',
      'range.subbar.color': '#d1d1d1',

      'range.disabledPointer.color': '#414141',
      'range.disabledBar.color': '#282828',
      'range.disabledSubbar.color': '#414141',

      'range.value.color': '#fff',
      'range.value.fontWeight': 'lighter',
      'range.value.fontSize': '11px',
      'range.value.border': '1px solid #353535',
      'range.value.backgroundColor': '#151515',
      'range.title.color': '#fff',
      'range.title.fontWeight': 'lighter',

      // colorpicker style
      'colorpicker.button.border': '1px solid #1e1e1e',
      'colorpicker.title.color': '#fff'
    };

    const options = {
      usageStatistics: false,
      includeUI: {
        loadImage: {
          path: this.fileUrl,
          name: this.fileName
        },
        // locale: locale_ru_RU,
        theme: blackTheme, // or whiteTheme
        initMenu: '',
        menu: ['resize', 'crop', 'flip', 'rotate', 'draw', 'text', 'filter'],
        uiSize: {
          width: '100vw',
          height: '92vh'
        }
      },
      cssMaxWidth: '1920',
      cssMaxHeight: '1080',
      selectionStyle: {
        cornerSize: 20,
        rotatingPointOffset: 70
      }
    };

    TuiImageEditor().then(tuiImageEditor => {
      this.editor = new tuiImageEditor(this.$reveal.find('.tui-image-editor').get(0), options);
    });
  }
  handleSave(event) {
    event.preventDefault();
    event.stopPropagation();

    let newUrl = this.editor.toDataURL({ format: this.fileFormat });

    this.updateAsset(newUrl, true);
  }
  initFile() {
    this.updateAsset(this.fileUrl);
  }
  updateAsset(fileUrl, closeOverlay = false) {
    const fileName = this.fileName + '.' + this.fileFormat;

    DataCycle.disableElement(this.saveButton);

    this.urlToFile(fileUrl, fileName, this.fileMimeType)
      .then(file => {
        let data = new FormData();
        data.append('asset[file]', file);
        data.append('asset[type]', 'DataCycleCore::Image');
        data.append('asset[name]', fileName);
        data.append('variant', true);
        const url = '/files/assets';
        const type = 'POST';
        const promise = DataCycle.httpRequest({
          url: url,
          method: type,
          enctype: 'multipart/form-data',
          data: data,
          dataType: 'json',
          processData: false,
          contentType: false,
          cache: false
        });

        promise
          .then(async data => {
            if (data.error) {
              if (closeOverlay) this.handleError(data.error);
              return;
            }

            this.editableList.trigger('dc:import:data', data);

            if (closeOverlay) this.$reveal.foundation('close');
          })
          .catch(async data => {
            let error = data.statusText;
            if (data && data.responseJSON && data.responseJSON.error) error = data.responseJSON.error;
            console.error('error saving image:', error);

            const errorMessage = await I18n.t('frontend.image_editor.save_error');
            this.handleError(errorMessage);
          })
          .finally(() => {
            DataCycle.enableElement(this.saveButton);
          });
      })
      .catch(error => {
        console.error('error', error);

        DataCycle.enableElement(this.saveButton);
      });
  }
  handleError(e) {
    CalloutHelpers.show(e, 'alert');
  }
  urlToFile(url, filename, mimeType) {
    return fetch(url)
      .then(res => res.blob())
      .then(blob => new File([blob], filename, { type: mimeType || blob.type }));
  }
}

export default ImageEditor;
