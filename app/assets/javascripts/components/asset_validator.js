import get from "lodash/get";
import omit from "lodash/omit";
import MimeTypes from "mime/lite";

class AssetValidator {
	constructor(file) {
		this.file = file;
		this.dimensionConstants = [
			{
				type: "min",
				attribute: "width",
				method: (a, b) => a < b,
			},
			{
				type: "min",
				attribute: "height",
				method: (a, b) => a < b,
			},
			{
				type: "max",
				attribute: "width",
				method: (a, b) => a > b,
			},
			{
				type: "max",
				attribute: "height",
				method: (a, b) => a > b,
			},
		];
	}
	async validate() {
		let valid = true;
		const messages = [];
		for (const key in this.file.validation) {
			const validationMethod = `validate_${key}`.camelize();
			if (typeof this[validationMethod] === "function") {
				const validationValue = await this[validationMethod](
					this.file.validation[key],
				);
				valid &= validationValue.valid;
				if (validationValue.message) messages.push(validationValue.message);
			}
		}
		return {
			valid: valid,
			messages: messages,
		};
	}
	async validateFileSize(validations) {
		const messages = [];
		let valid = true;
		if (
			validations.max !== undefined &&
			this.file.file.size > validations.max
		) {
			valid = false;
			messages.push(
				await I18n.translate("uploader.validation.file_size.max", {
					data: validations.max.file_size(0),
				}),
			);
		}
		if (
			validations.min !== undefined &&
			this.file.file.size < validations.min
		) {
			valid = false;
			messages.push(
				await I18n.translate("uploader.validation.file_size.min", {
					data: validations.min.file_size(0),
				}),
			);
		}
		return {
			valid: valid,
			message: valid ? undefined : messages.join(", "),
		};
	}
	async validateFormat(validations) {
		validations.forEach((format) => {
			const mimeType = MimeTypes.getType(format);
			if (mimeType)
				validations = validations.concat(MimeTypes.getExtension(mimeType));
		});

		var valid = validations.indexOf(this.file.fileExtension) !== -1;

		return {
			valid: valid,
			message: valid
				? undefined
				: await I18n.translate("uploader.validation.format_not_supported", {
						data: this.file.fileExtension,
					}),
		};
	}
	async validateDimensions(validations) {
		var additional = omit(validations, ["landscape", "portrait", "exclude"]);

		if (this.file.validationOptions !== undefined) {
			if (
				get(validations, "exclude.format") !== null &&
				get(validations, "exclude.format").indexOf(this.file.fileExtension) !==
					-1
			) {
				return {
					valid: true,
					message: undefined,
				};
			}
			for (var key in additional) {
				if (
					additional[key].max !== undefined &&
					((additional[key].max.height !== undefined &&
						this.file.validationOptions.height <= additional[key].max.height) ||
						(additional[key].max.width !== undefined &&
							this.file.validationOptions.width <= additional[key].max.width))
				) {
					return {
						valid: true,
						message: undefined,
					};
				}
				if (
					additional[key].min !== undefined &&
					((additional[key].min.height !== undefined &&
						this.file.validationOptions.height >= additional[key].min.height) ||
						(additional[key].min.width !== undefined &&
							this.file.validationOptions.width >= additional[key].min.width))
				) {
					return {
						valid: true,
						message: undefined,
					};
				}
			}

			const messages = [];
			const layout =
				this.file.validationOptions.width >= this.file.validationOptions.height
					? "landscape"
					: "portrait";

			for (let i = 0; i < this.dimensionConstants.length; ++i) {
				const val = this.dimensionConstants[i];

				if (
					get(validations, `${layout}.${val.type}.${val.attribute}`) &&
					val.method(
						get(this.file.validationOptions, val.attribute),
						validations[layout][val.type][val.attribute],
					)
				)
					messages.push(
						await I18n.translate(
							`uploader.validation.dimensions.${layout}.${val.type}.${val.attribute}`,
							{
								data: validations[layout][val.type][val.attribute],
							},
						),
					);
			}

			if (messages.length) {
				return {
					valid: false,
					message: messages.join(", "),
				};
			} else {
				return {
					valid: true,
					message: undefined,
				};
			}
		}
		return {
			valid: true,
			message: undefined,
		};
	}
}

export default AssetValidator;
