import Validator from "./validator";

class BulkUpdateValidator extends Validator {
	constructor(formElement) {
		super(formElement);

		this.uuid = this.$form.find(":hidden#uuid").val();

		this.setup();
	}
	setup() {
		this.initActionCable();
	}
	initActionCable() {
		window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::WatchListBulkUpdateChannel",
				watch_list_id: this.uuid,
			},
			{
				received: (data) => {
					if (!this.$submitButton.prop("disabled")) this.disable();
					if (data.progress !== undefined) {
						const progress = Math.round((data.progress * 100) / data.items);
						this.$submitButton.find(".progress-value").text(`${progress}%`);
						this.$submitButton
							.find(".progress-bar > .progress-filled")
							.css("width", `calc(${progress}% - 1rem)`);
					}
					if (data.redirect_path !== undefined) {
						window.location.href = data.redirect_path;
					}
				},
			},
		);
	}
	bulkUpdateEnabled(item) {
		return !!item.querySelector(
			`.dc-bulk_update-type[data-attribute-key="${$(item).data("key")}"] input[type="checkbox"]:checked`,
		);
	}
	validateItem(validationContainer) {
		if (
			!$(validationContainer).hasClass("agbs") &&
			!this.bulkUpdateEnabled(validationContainer)
		)
			return Promise.resolve({ valid: true });

		return super.validateItem(validationContainer);
	}
}

export default BulkUpdateValidator;
