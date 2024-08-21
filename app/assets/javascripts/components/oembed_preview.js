class OembedPreview {

    constructor() {
    }

    validate_oembed(baseUrlInput, dataHash) {

        const url = baseUrlInput.value;

        const previewTargetBaseId = "#"+baseUrlInput.id;
        const previewTargetSpinnerId = previewTargetBaseId+"_spinner";
        const previewTarget = previewTargetBaseId+"_oembed_preview";

        $(previewTargetSpinnerId).show();

        $.getJSON(window.location.origin+'/oembed?url='+url)
            .then(response => {
                $(previewTarget).html(response.html);
                $(previewTargetSpinnerId).hide();
            })
            .catch(errorResponse => {
                $(previewTarget).html(this.prettyErrors(errorResponse.responseJSON.errors));
                $(previewTargetSpinnerId).hide();
            })

    }

    prettyErrors(errors){
        let errorToDisplay;
        if (Array.isArray(errors) && errors.length>0){
            errorToDisplay = errors[errors.length-1];
        } else if (errors.length > 0){
            errorToDisplay = errors;
        } else {
            errorToDisplay = "";
        }

        let errorDiv = document.createElement("div");
        errorDiv.innerHTML = `<i class="fa fa-exclamation-triangle" aria_hidden="true"></i> &nbsp;`;
        errorDiv.innerHTML += `<span>${errorToDisplay}</span>`;
        errorDiv.className='toast-notification alert';

        return errorDiv;

    }
}

export default OembedPreview;