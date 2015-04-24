// Just in as a placeholder for now, only works in Safari (as far as I can tell)
var SpotConnect = function() {};

SpotConnect.prototype = {
    
run: function(parameters) {
    // Return the url and title of the page
    parameters.completionFunction({"URL": document.URL, "title": document.title });
},
    
finalize: function(parameters) {
    
}
};
var ExtensionPreprocessingJS = new SpotConnect