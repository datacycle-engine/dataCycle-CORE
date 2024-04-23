export default (() => {
	String.prototype.attributeNameFromKey = function () {
		return this.split(/[\[\]]+/)
			.filter((elem) => elem?.length)
			.pop();
	};
	String.prototype.normalizeKey = function () {
		return this.replace("[]", "");
	};
	String.prototype.isUuid = function () {
		return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
			this,
		);
	};
	String.prototype.camelize = function () {
		return this.replace(/_+(.)/g, (_match, chr) => chr.toUpperCase());
	};
	String.prototype.interpolate = function (params) {
		const names = Object.keys(params);
		const vals = Object.values(params);
		return new Function(...names, `return \`${this}\`;`)(...vals);
	};
	String.prototype.sanitizeToId = function () {
		return this.replaceAll("]", "").replaceAll(/[^-a-zA-Z0-9:\._]/g, "_");
	};
})();
