const VideoJs = () => import('video.js').then(mod => mod.default);

class VideoPlayer {
  constructor(videoObject) {
    videoObject.dcVideoPlayer = true;

    VideoJs().then(videoJs => {
      this.player = videoJs(videoObject, {
        controls: true
      });
    });
  }
}

export default VideoPlayer;
