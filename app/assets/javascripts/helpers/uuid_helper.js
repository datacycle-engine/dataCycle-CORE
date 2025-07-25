import isString from "lodash/isString";

export default {
	isUuid: (value) => {
		if (!isString(value)) return false;

		return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
			value,
		);
	},
};
