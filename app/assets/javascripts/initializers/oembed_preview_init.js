import OembedPreview from "../components/oembed_preview";


export default function () {

    let oembedPreview=new OembedPreview();
    init();

    function init() {

        DataCycle.registerAddCallback(
            "input.oembed-input",
            "oembed-preview",
            (element) => {
                let oembedData = JSON.parse(element.getAttribute('oembed_preview') || "{}");
                oembedPreview.validate_oembed(element, oembedData);

                element.addEventListener('blur', function (event){
                    let elem = event.target;
                    let oembedData = JSON.parse(elem.getAttribute('oembed_preview') || "{}");
                    oembedPreview.validate_oembed(elem, oembedData);
                })

            }
        );
    }
}