import VideoJs from 'video.js';

class VideoPlayer {
  constructor(videoObject) {
    const player = VideoJs(videoObject, {
      controls: true,
    });
  }
}

export default VideoPlayer;
