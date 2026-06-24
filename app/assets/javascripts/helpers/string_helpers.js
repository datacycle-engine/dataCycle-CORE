export default (() => {
	String.prototype.attributeNameFromKey = function () {
		return this.split(/[[\]]+/)
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
		return this.replace(/\${([^}]+)}/g, (match, key) => {
			return Object.hasOwn(params, key.trim()) ? params[key.trim()] : match;
		});
	};
	String.prototype.sanitizeToId = function () {
		return this.replaceAll("]", "").replaceAll(/[^-a-zA-Z0-9:._]/g, "_");
	};
})();
