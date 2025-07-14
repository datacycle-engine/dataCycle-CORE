export default (() => {
	Object.defineProperty(Number.prototype, "file_size", {
		value: function (a, b, c, d) {
			return (
				((a = a ? [1e3, "k", "B"] : [1024, "K", "iB"]),
				(b = Math),
				(c = b.log),
				(d = (c(this) / c(a[0])) | 0),
				this / b.pow(a[0], d)).toFixed(2) +
				" " +
				(d ? (a[1] + "MGTPEZY")[--d] + a[2] : "Bytes")
			);
		},
		writable: false,
		enumerable: false,
	});
})();
