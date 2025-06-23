export default {
	seconds_to_human_time: (secs) => {
		const hours = Math.floor(secs / 3600);
		const minutes = Math.floor((secs - hours * 3600) / 60);
		const seconds = Math.round(secs - hours * 3600 - minutes * 60);

		return `${hours < 10 ? `0${hours}` : hours}:${minutes < 10 ? `0${minutes}` : minutes}:${seconds < 10 ? `0${seconds}` : seconds}`;
	},
};
