import CalloutHelpers from "../helpers/callout_helpers";

class RebuildClassificationMappings {
	constructor(item) {
		this.item = item;

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.clickButton.bind(this));
		if (this.item.dataset.disabled === "true")
			DataCycle.disableElement(this.item);

		this.initActionCable();
	}
	initActionCable() {
		window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::RebuildClassificationMappingsChannel",
			},
			{
				received: (data) => {
					if (data.message_path)
						this.renderMessage(
							data.message_path,
							data.message_type || "success",
						);

					if (data.type === "lock") DataCycle.disableElement(this.item);
					else if (data.type === "unlock") DataCycle.enableElement(this.item);
				},
			},
		);
	}
	clickButton(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.httpRequest(this.item.href);
	}
	renderMessage(path, message_type) {
		I18n.t(path).then((text) => CalloutHelpers.show(text, message_type));
	}
}

export default RebuildClassificationMappings;
