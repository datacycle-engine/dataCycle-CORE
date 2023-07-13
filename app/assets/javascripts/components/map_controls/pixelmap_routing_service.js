const PixelmapRoutingService = {
	async route({ locations, token, costing, host }) {
		const options = {
			costing: costing,
			units: "km",
			language: "de-DE",
			locations: locations,
		};

		const fetchOptions = {};
		if (token) fetchOptions.headers = { Authorization: `Bearer ${token}` };

		const url = new URL("route", host);
		url.searchParams.set("json", JSON.stringify(options));

		const response = await fetch(url, fetchOptions);
		const jsonData = await response.json();

		return this.decode(jsonData?.trip?.legs[0]?.shape, 6);
	},
	decode(str, precision) {
		if (!str) return;

		let index = 0;
		let lat = 0;
		let lng = 0;
		const coordinates = [];
		let shift = 0;
		let result = 0;
		let byte = null;
		let latitude_change;
		let longitude_change;
		const factor = Math.pow(10, precision || 6);

		// Coordinates have variable length when encoded, so just keep
		// track of whether we've hit the end of the string. In each
		// loop iteration, a single coordinate is decoded.
		while (index < str.length) {
			// Reset shift, result, and byte
			byte = null;
			shift = 0;
			result = 0;

			do {
				byte = str.charCodeAt(index++) - 63;
				result |= (byte & 0x1f) << shift;
				shift += 5;
			} while (byte >= 0x20);

			latitude_change = result & 1 ? ~(result >> 1) : result >> 1;

			shift = result = 0;

			do {
				byte = str.charCodeAt(index++) - 63;
				result |= (byte & 0x1f) << shift;
				shift += 5;
			} while (byte >= 0x20);

			longitude_change = result & 1 ? ~(result >> 1) : result >> 1;

			lat += latitude_change;
			lng += longitude_change;

			coordinates.push([lat / factor, lng / factor]);
		}

		return coordinates;
	},
};

Object.freeze(PixelmapRoutingService);

export default PixelmapRoutingService;
