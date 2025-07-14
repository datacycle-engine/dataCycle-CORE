export default {
	progress: (event, container) => {
		var percentage = (event.loaded * 100) / event.total;
		if (container.find(".progressbar > .progressbar-meter").length) {
			container
				.find(".progressbar > .progressbar-meter")
				.css("width", `${percentage}%`);
		} else {
			const text = container.html();
			container.html("");
			container.append(
				`<span class="progresstitle">${text}</span><span class="progressbar"><span class="progressbar-meter style="width: ${percentage}%;"></span></span>`,
			);
		}

		if (percentage >= 100) {
			const text = container.find(".progresstitle").html();
			container.find(".progressbar").fadeOut(500, () => {
				container.html(text);
			});
		}
	},
};
