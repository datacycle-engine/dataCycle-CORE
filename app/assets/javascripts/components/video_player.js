import VideoJs from 'video.js';

class VideoPlayer {
  constructor(videoObject) {
    videoObject.dcVideoPlayer = true;
    this.player = VideoJs(videoObject, {
      controls: true
    });
  }
}

export default VideoPlayer;
