class AiLector {
	constructor() {
		this.channelConnected = false;
		this.channel = window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::AiLectorChannel",
				window_id: DataCycle.windowId,
			},
			{
				received: this.received.bind(this),
			},
		);
	}
	send(data) {
		const sent = this.channel.send(data);
		if (!sent) throw new Error("Could not send data");
	}
	received(data) {
		this.notifyTarget(data);
	}
	notifyTarget(data) {
		const target = document.getElementById(data.identifier);
		if (target) target.dispatchEvent(new CustomEvent("data", { detail: data }));
	}
}

export default AiLector;
