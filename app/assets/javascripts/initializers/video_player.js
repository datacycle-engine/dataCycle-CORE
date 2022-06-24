import VideoPlayer from '../components/video_player';

export default function () {
  init();

  function init(element = document) {
    $(element)
      .find('.video-js')
      .each((_, elem) => {
        new VideoPlayer(elem);
      });
  }
}
