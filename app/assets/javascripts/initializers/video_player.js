import VideoPlayer from '../components/video_player';

export default function () {
  init();

  function init(element = document) {
    console.log('wuhu')
    $(element)
      .find('.video-js')
      .each((_, elem) => {
        new VideoPlayer(elem);
      });
  }
}
