export default (() => {
	document.addEventListener("lazybeforeunveil", async (e) => {
		const target = e.target;

		if (target.dataset.base64Uri) {
			e.preventDefault();

			const dataUri = await $.get(target.dataset.base64Uri);
			if (dataUri) target.src = `data:image/png;base64, ${dataUri}`;
		}
	});
})();
