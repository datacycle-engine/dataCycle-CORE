import { showCallout } from "../../helpers/callout_helpers";
import { formDataToObject } from "../../helpers/dom_element_helpers";

class ConceptSchemeLinkForm {
	static #channel = "DataCycleCore::ConceptSchemeLinkChannel";

	constructor(item, key, linkType) {
		this.item = item;
		this.key = key;
		this.linkType = linkType;
		this.progressBarContainer = this.item.querySelector(".progress");
		this.progressElement =
			this.progressBarContainer.querySelector(".progress-meter");
		this.progressText = this.progressBarContainer.querySelector(
			".progress-meter-text",
		);
		this.postSubmitText = this.item.querySelector(".post-submit-text");
		this.postSubmitButton = this.item.querySelector("button.post-submit");
		this.postSubmitContainer = this.item.querySelector(".post-submit.step");
		this.postSubmitResult = this.item.querySelector(".post-submit-result-body");

		this.init();
	}
	init() {
		this.item.addEventListener("dc:form:step", this.checkStepAction.bind(this));
		this.item.addEventListener("submit", this.confirmSubmit.bind(this));
	}
	checkStepAction(event) {
		const { fieldset, action } = event.detail;
		if (action === "next" && fieldset.dataset.stepIdentifier === "warning") {
			fieldset.dispatchEvent(
				new CustomEvent("dc:remote:reloadOnNextOpen", {
					detail: this.warningData(),
				}),
			);
		}
	}
	warningData() {
		const formData = new FormData(this.item);
		const formDataObject = formDataToObject(formData);
		const collection_id = formDataObject.concept_scheme_link.collection_id;

		return {
			collection_id: collection_id,
		};
	}
	async confirmSubmit(event) {
		event.preventDefault();
		event.stopPropagation();

		const formData = new FormData(this.item);
		const formDataObject = formDataToObject(formData);
		const collection_id = formDataObject.concept_scheme_link.collection_id;
		const concept_scheme_id = formDataObject.concept_scheme_link.id;
		DataCycle.disableElement(this.postSubmitButton);
		this.clearResult();
		this.setProgress(0);
		await this.initActionCable(collection_id, concept_scheme_id);
		this.submitData(formData);
	}
	submitData(formData) {
		// the rejection reason must not reach showGenericError — as a key it built
		// "concept_scheme_link.Error: 401" and rendered that instead of a message
		DataCycle.httpRequest(this.item.action, {
			method: this.item.method,
			body: formData,
		}).catch(() => this.showGenericError());
	}
	showGenericError(key = "error") {
		I18n.t(`concept_scheme_${this.key}.${key}`).then((t) =>
			this.actionFinished(t, "alert"),
		);
		DataCycle.enableElement(this.postSubmitButton);
	}
	async initActionCable(collection_id, concept_scheme_id) {
		const cable = await DataCycle.cable;
		if (this.subscription) this.subscription.unsubscribe();

		// ActionCable's own `reconnected` flag is only set when its stale-poll drove the reopen — the one
		// a visibilitychange triggers looks like a first connect — so recognize a reconnect ourselves
		let seenConnect = false;

		this.subscription = cable.subscriptions.create(
			{
				channel: ConceptSchemeLinkForm.#channel,
				collection_id: collection_id,
				concept_scheme_id: concept_scheme_id,
				key: this.key,
			},
			{
				connected: () => {
					if (seenConnect) this.subscription.perform("resync");
					seenConnect = true;
				},
				received: (data) => {
					if (data.type === "error") {
						return I18n.t(`concept_scheme_${this.key}.error`).then((t) =>
							showCallout(t, "alert"),
						);
					}

					if (data.error) showCallout(data.error, "alert");

					if (data.finished) this.finishedResult(data);
					else if (Object.hasOwn(data, "progress"))
						this.showProgress(data.progress);
				},
				// ActionCable reopens the socket for anything from a missed ping to a backgrounded tab
				// (its own stale check trips on throttled timers) and resubscribes on its own, so only a
				// drop it will not retry means the run can no longer be followed
				disconnected: ({ willAttemptReconnect } = {}) => {
					if (!willAttemptReconnect) this.showGenericError("disconnected");
				},
				rejected: this.showGenericError.bind(this, "error"),
			},
		);
	}
	actionFinished(message, calloutClass = "success") {
		this.postSubmitText.innerHTML = `<div class="callout ${calloutClass}">${message}</div>`;
		this.statusFinished();
	}
	finishedResult(data) {
		if (data.result) {
			this.postSubmitContainer.classList.add("finished");

			for (const value of data.result) {
				const statusIcon = value.valid ? "check" : "times";
				const color = value.valid ? "success" : "alert";
				const errorMessage = value.error || "";

				this.postSubmitResult.insertAdjacentHTML(
					"beforeend",
					`<tr>
            <td>${value.concept_scheme_name}</td>
            <td>${value.collection_name}</td>
            <td>${value.count}</td>
            <td><i class="fa fa-${statusIcon} ${color}-color" aria-hidden="true" data-dc-tooltip="${errorMessage}"></i></td>
          </tr>`,
				);
			}
		}

		this.statusFinished();
	}
	statusFinished() {
		DataCycle.enableElement(this.postSubmitButton);
		this.progressBarContainer.classList.remove("visible");
		if (this.subscription) this.subscription.unsubscribe();
	}
	clearResult() {
		this.postSubmitContainer.classList.remove("finished");
		this.postSubmitResult.innerHTML = "";
	}
	showProgress(progress) {
		this.progressBarContainer.classList.add("visible");
		this.setProgress(progress);
	}
	setProgress(progress) {
		this.progressElement.style.width = `${progress}%`;
		this.progressText.textContent = `${progress}%`;
	}
}

export default ConceptSchemeLinkForm;
