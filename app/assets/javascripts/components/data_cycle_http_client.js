const DataCycleHttpClient = {
	joinPath(...segments) {
		const parts = segments.reduce((parts, segment) => {
			if (!segment) return parts;

			let s = segment;

			if (parts.length > 0) s = s.replace(/^\//, "");

			s = s.replace(/\/$/, "");

			return parts.concat(s.split("/"));
		}, []);

		const resultParts = [];

		for (const part of parts) {
			if (part === ".") continue;
			if (part === "..") {
				resultParts.pop();
				continue;
			}

			resultParts.push(part);
		}

		return resultParts.join("/");
	},
	wait(delay) {
		return new Promise((resolve) => setTimeout(resolve, delay));
	},
	defaultHttpHeaders() {
		return {
			"X-CSRF-Token": document.getElementsByName("csrf-token")[0].content,
			Accept: "application/json",
		};
	},
	flattenParamsRecursive(key, value, params = []) {
		if (Array.isArray(value))
			for (const v of value) this.flattenParamsRecursive(`${key}[]`, v, params);
		else if (typeof value === "object" && value !== null && value !== undefined)
			for (const [k, v] of Object.entries(value))
				this.flattenParamsRecursive(`${key}[${k}]`, v, params);
		else params.push([key, value]);

		return params;
	},
	objectToUrlSearchParams(object) {
		const params = new URLSearchParams();

		for (const [key, value] of Object.entries(object))
			for (const [k, v] of this.flattenParamsRecursive(key, value))
				params.append(k, v);

		return params;
	},
	mergeHttpOptions(urlParam, options) {
		let url = urlParam;
		if (!options.method) options.method = "GET";
		else options.method = options.method.toUpperCase();

		options.headers = Object.assign(this.defaultHttpHeaders(), options.headers);

		if (this.config.EnginePath && !url.includes(this.config.EnginePath))
			url = this.joinPath(this.config.EnginePath, url);

		if (!(options.body instanceof FormData || options.headers["Content-Type"]))
			options.headers["Content-Type"] = "application/json";

		if (options.method === "GET" && options.body) {
			url += `?${this.objectToUrlSearchParams(options.body).toString()}`;
			options.body = undefined;
		} else if (
			options.headers["Content-Type"] === "application/json" &&
			options.body &&
			typeof options.body !== "string" &&
			!(options.body instanceof String)
		)
			options.body = JSON.stringify(options.body);

		if (
			(options.method !== "GET" && options.method !== "POST") ||
			options.body instanceof FormData
		)
			options.cache = "no-cache";

		return [url, options];
	},
	httpRequest(url, options = {}, retries = 3) {
		const [mergedUrl, mergedOptions] = this.mergeHttpOptions(url, options);

		return fetch(mergedUrl, mergedOptions).then(async (res) => {
			if (res.ok) {
				return res.json().catch(() => undefined);
			}

			if (
				retries > 0 &&
				this.config.retryableHttpCodes.includes(res.status) &&
				import.meta.env.PROD
			)
				return this.wait(1000 * (3 / retries)).then(() =>
					this.httpRequest(mergedUrl, mergedOptions, retries - 1),
				);

			const error = new Error(res.status);
			error.responseBody = await res.json().catch(() => undefined);

			throw error;
		});
	},
};

Object.freeze(DataCycleHttpClient);

export default DataCycleHttpClient;
