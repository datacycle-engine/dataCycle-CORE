const ObjectUtilities = {
	isObject(value) {
		return ["object", "function"].includes(typeof value) && value !== null;
	},
	get(object, originalPath, defaultValue = undefined) {
		let path = originalPath;

		if (typeof path === "string") {
			path = path.split(/[.\[\]\"]+/).filter((x) => x);
		}

		if (path.length === 0) {
			return object;
		}

		const [head, ...tail] = path;
		if (!(head in object)) {
			return defaultValue;
		}

		return this.get(object[head], tail, defaultValue);
	},
	set(object, originalPath, value) {
		let path = originalPath;

		if (typeof path === "string") {
			const isQuoted = (str) => str[0] === '"' && str.at(-1) === '"';
			path = path
				.split(/[.\[\]]+/)
				.filter((x) => x)
				.map((x) => (!Number.isNaN(Number(x)) ? Number(x) : x))
				.map((x) =>
					typeof x === "string" && isQuoted(x) ? x.slice(1, -1) : x,
				);
		}

		if (path.length === 0) {
			throw new Error("The path must have at least one entry in it");
		}

		const [head, ...tail] = path;

		if (tail.length === 0) {
			object[head] = value;
			return object;
		}

		if (!(head in object)) {
			object[head] = typeof tail[0] === "number" ? [] : {};
		}

		this.set(object[head], tail, value);
		return object;
	},
	merge(object, ...sources) {
		if (!this.isObject(object)) {
			throw new Error(`Expected ${object} to be an object.`);
		}

		for (const source of sources) {
			for (const [key, value] of Object.entries(source)) {
				if (value === undefined) {
					continue;
				}

				if (object[key] === undefined) {
					object[key] = value;
				} else {
					this.merge(object[key], value);
				}
			}
		}

		return object;
	},
	pick(object, keys) {
		if (object == null) {
			return {};
		}
		const newObject = {};

		for (const key of keys) {
			let keyPath;
			if (typeof key === "string") {
				keyPath = key.split(/[.\[\]\"]+/).filter((x) => x);
			} else if (Array.isArray(key)) {
				keyPath = key;
			} else {
				throw new Error(`Received a key ${key}, which is of an invalid type.`);
			}

			const [head, ...tail] = keyPath;
			if (!(head in object)) {
			} else if (tail.length === 0) {
				newObject[key] = object[key];
			} else if (this.isObject(object[head]) || Array.isArray(object[head])) {
				newObject[head] = {
					...(newObject[head] ?? {}),
					...this.pick(object[head], [tail]),
				};
			}
		}

		return newObject;
	},
};

Object.freeze(ObjectUtilities);

export default ObjectUtilities;
