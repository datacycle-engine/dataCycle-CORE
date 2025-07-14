import VideoPlayer from "../components/video_player";

export default function () {
	init();

	function init(element = document) {
		for (const elem of element.querySelectorAll(".video-js"))
			new VideoPlayer(elem);
	}
}
