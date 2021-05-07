import MimeTypes from 'mime/lite';
import ObjectHelpers from './../helpers/object_helpers';

class AssetValidator {
  constructor(file) {
    this.file = file;
  }
  validate() {
    let valid = true;
    let messages = [];
    for (let key in this.file.validation) {
      let validationMethod = ('validate_' + key).camelize();
      if (typeof this[validationMethod] == 'function') {
        let validationValue = this[validationMethod](this.file.validation[key]);
        valid &= validationValue.valid;
        if (validationValue.message) messages.push(validationValue.message);
      }
    }
    return {
      valid: valid,
      messages: messages
    };
  }
  validateFileSize(validations) {
    let messages = '';
    let valid = true;
    if (validations.max !== undefined && this.file.file.size > validations.max) {
      valid = false;
      messages += 'Datei zu groß (maximal ' + validations.max.file_size(0) + ')';
    }
    if (validations.min !== undefined && this.file.file.size < validations.min) {
      valid = false;
      messages += 'Datei zu klein (mindestens ' + validations.min.file_size(0) + ')';
    }
    return {
      valid: valid,
      message: valid ? undefined : messages
    };
  }
  validateFormat(validations) {
    validations.forEach(format => {
      let mimeType = MimeTypes.getType(format);
      if (mimeType) validations = validations.concat(MimeTypes.getExtension(mimeType));
    });

    var valid = validations.indexOf(this.file.fileExtension) !== -1;

    return {
      valid: valid,
      message: valid ? undefined : 'Nicht unterstützes Format (' + this.file.fileExtension + ')'
    };
  }
  validateDimensions(validations) {
    if (this.file.validationOptions !== undefined) {
      var additional = ObjectHelpers.reject(validations, ['landscape', 'portrait', 'exclude']);
      if (
        ObjectHelpers.get(['exclude', 'format'], validations) !== null &&
        ObjectHelpers.get(['exclude', 'format'], validations).indexOf(this.file.fileExtension) !== -1
      ) {
        return {
          valid: true,
          message: undefined
        };
      }
      for (var key in additional) {
        if (
          additional[key].max !== undefined &&
          ((additional[key].max.height !== undefined &&
            this.file.validationOptions.height <= additional[key].max.height) ||
            (additional[key].max.width !== undefined && this.file.validationOptions.width <= additional[key].max.width))
        ) {
          return {
            valid: true,
            message: undefined
          };
        }
        if (
          additional[key].min !== undefined &&
          ((additional[key].min.height !== undefined &&
            this.file.validationOptions.height >= additional[key].min.height) ||
            (additional[key].min.width !== undefined && this.file.validationOptions.width >= additional[key].min.width))
        ) {
          return {
            valid: true,
            message: undefined
          };
        }
      }
      if (
        (this.file.validationOptions.width >= this.file.validationOptions.height &&
          ((ObjectHelpers.get(['landscape', 'min', 'width'], validations) !== null &&
            this.file.validationOptions.width < validations.landscape.min.width) ||
            (ObjectHelpers.get(['landscape', 'min', 'height'], validations) !== null &&
              this.file.validationOptions.height < validations.landscape.min.height))) ||
        (this.file.validationOptions.width < this.file.validationOptions.height &&
          ((ObjectHelpers.get(['portrait', 'min', 'width'], validations) !== null &&
            this.file.validationOptions.width < validations.portrait.min.width) ||
            (ObjectHelpers.get(['portrait', 'min', 'height'], validations) !== null &&
              this.file.validationOptions.height < validations.portrait.min.height)))
      ) {
        var message =
          'Bild zu klein (' +
          this.file.validationOptions.width +
          'x' +
          this.file.validationOptions.height +
          '), sollte' +
          (ObjectHelpers.get(['landscape', 'min'], validations) !== null
            ? ' für Querformat mind. ' +
              ObjectHelpers.get(['landscape', 'min', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['landscape', 'min', 'height'], validations)
            : '') +
          (ObjectHelpers.get(['landscape', 'min'], validations) !== null &&
          ObjectHelpers.get(['portrait', 'min'], validations) !== null
            ? ','
            : '') +
          (ObjectHelpers.get(['portrait', 'min'], validations) !== null
            ? ' für Hochformat mind. ' +
              ObjectHelpers.get(['portrait', 'min', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['portrait', 'min', 'height'], validations)
            : '') +
          ' sein.';
        return {
          valid: false,
          message: message
        };
      }
      if (
        (this.file.validationOptions.width >= this.file.validationOptions.height &&
          ((ObjectHelpers.get(['landscape', 'max', 'width'], validations) !== null &&
            this.file.validationOptions.width > validations.landscape.max.width) ||
            (ObjectHelpers.get(['landscape', 'max', 'height'], validations) !== null &&
              this.file.validationOptions.height > validations.landscape.max.height))) ||
        (this.file.validationOptions.width < this.file.validationOptions.height &&
          ((ObjectHelpers.get(['portrait', 'max', 'width'], validations) !== null &&
            this.file.validationOptions.width > validations.portrait.max.width) ||
            (ObjectHelpers.get(['portrait', 'max', 'height'], validations) !== null &&
              this.file.validationOptions.height > validations.portrait.max.height)))
      ) {
        var message =
          'Bild zu groß (' +
          this.file.validationOptions.width +
          'x' +
          this.file.validationOptions.height +
          '), sollte' +
          (ObjectHelpers.get(['landscape', 'max'], validations) !== null
            ? ' für Querformat max. ' +
              ObjectHelpers.get(['landscape', 'max', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['landscape', 'max', 'height'], validations)
            : '') +
          (ObjectHelpers.get(['landscape', 'max'], validations) !== null &&
          ObjectHelpers.get(['portrait', 'max'], validations) !== null
            ? ','
            : '') +
          (ObjectHelpers.get(['portrait', 'max'], validations) !== null
            ? ' für Hochformat max. ' +
              ObjectHelpers.get(['portrait', 'max', 'width'], validations) +
              'x' +
              ObjectHelpers.get(['portrait', 'max', 'height'], validations)
            : '') +
          ' sein.';
        return {
          valid: false,
          message: message
        };
      }
    }
    return {
      valid: true,
      message: undefined
    };
  }
}

export default AssetValidator;
