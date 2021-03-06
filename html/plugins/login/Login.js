console.log("plugins.login.Login    LOADING");

/* DISPLAY A LOGIN DIALOGUE WINDOW AND AUTHENTICATE

	WITH THE REMOTE DATABASE TO RETRIEVE A SESSION ID 

	AND STORE IT IN Agua.cookie("sessionid")
*/

define([
	"dojo/_base/declare",
	"dijit/_Widget",
	"dijit/_TemplatedMixin",
	"dijit/_WidgetsInTemplateMixin",
	"plugins/core/Common",
	"plugins/login/LoginStatus",
	//"dojo/domReady!"
	//,
	
	"dojox/widget/Dialog",
	"dijit/form/Button",
	"dijit/form/TextBox",
	"dojo/fx/easing",
	"dijit/ProgressBar",
],

function (
	declare,
	_Widget,
	_TemplatedMixin,
	_WidgetsInTemplate,
	Common,
	LoginStatus
) {

///////}}}}}

window.Agua = Agua;

return declare("plugins.login.Login",
	[
	_Widget,
	_TemplatedMixin,
	_WidgetsInTemplate,
	Common
], {


// templateString : String
//		The template of this widget. 
templateString: dojo.cache("plugins", "login/templates/login.html"),

// loginMessage : String
//		Display this login prompt message
loginMessage : "",

cssFiles: [
	require.toUrl("plugins/login/css/login.css"),
	require.toUrl("dojox/widget/Dialog/Dialog.css"),
	require.toUrl("dijit/themes/claro/claro.css")
],

// logging : Bool
// True if logging in, false otherwise
logging : false,

////}}}}
constructor : function () {
	console.log("Login.constructor    plugins.login.Login.constructor()");

	this.loadCSS();
	
	// GENERATE LOGIN STATUS TABLE IN RIGHT SIDE OF AGUA TOOLBAR
	this.statusBar = new LoginStatus();
	this.statusBar.launcher.title = "Log In";
	var listener = dojo.connect(this.statusBar.launcher, "onclick", this, "show");
	this.statusBar.launcher.listener = listener;
	document.getElementById("loginHolder").appendChild(this.statusBar.containerNode);
},
postCreate : function() {
	console.log("Login.postCreate    plugins.workflow.Login.postCreate()");
	this.startup();
},
startup : function () {
    console.group("Login.startup");
	console.log("Login.startup    plugins.workflow.Login.startup()");

	this.inherited(arguments);
	
	// ADD CLASS TO DIALOGUE
	dojo.addClass(this.domNode, 'login');

	// SET LISTENERS
	this.setDialogListeners();
	
	// SET PROGRESS BAR
	this.setProgressBar();
	
	var data = this.debug();
	if ( data ) {
		this.handleLogin(data, data.username);
		return;
	}
	
	// SHOW LOGIN WINDOW
	this.show();	

    console.groupEnd("Login.startup");
},
debug : function () {
	console.log("Login.debug    caller: " + this.debug.caller.nom);
	
	// GET USERNAME FROM URL IF PRESENT
	var url = window.location.href;
	console.log("Login.debug    url: " + url);
	if ( ! url.match(/(.+?)\?([^\?]+),([^,]+)/) )
	{
		console.log("Login.debug    Not debugging. Setting this.debugFlag to FALSE and returning");
		return false;
	}
	console.log("Login.debug    Debugging");

	var username = url.match(/(.+?)\?([^\?]+?),([^,]+)/)[2];
	var sessionid = url.match(/(.+?)\?([^\?]+?),([^,]+)/)[3];
	var plugins;
	if ( url.match(/(.+?)\?([^\?]+),([^,]+?),([^,]+)$/) )
	{
		plugins = url.match(/(.+?)\?([^\?]+),([^,]+),([^,]+)$/)[4];
	}
	console.log("Login.debug    plugins: " + dojo.toJson(plugins));

	if ( plugins != null )
	{
		var array = plugins.split(/\./);
		console.log("Login.debug    array: " + dojo.toJson(array));
		
		var pluginsList = new Array;
		var pluginsArgs = new Array;
		for ( var i = 0; i < array.length; i++ )
		{
			if ( ! array[i].match(/^[^\(]+/) )	continue;
			var pluginName = array[i].match(/^([^\(]+)/)[1];
			pluginsList[i] = "plugins.";
			pluginsList[i] += pluginName;
			pluginsList[i] += ".Controller";

			if ( array[i].match(/^[^\(]+\(([^\)]+)\)/) ) {
				var args = array[i].match(/^[^\(]+\(([^\)]+)\)/)[1];
				console.log("Login.debug    args: ");
				console.dir({args:args});
				pluginsArgs[i] = args;
			}
		}
		Agua.pluginsList = pluginsList;
		Agua.pluginsArgs = pluginsArgs;
	}
	console.log("Login.debug    this.pluginsList: " + dojo.toJson(Agua.pluginsList));

	// SET AGUA COOKIE
	var response = {};
	response.username 	= 	username;
	response.sendtype	= 	"response";
	response.data 		= 	{};
	response.data.sessionid	=	"9999999999.9999.999";
	response.type	= "response";
	
	console.log("Login.debug    Returning response: " + dojo.toJson(Agua.pluginsList));

	return response;	
},
setDialogListeners : function () {
	// FOCUS ON PASSWORD INPUT IF 'RETURN' KEY PRESSED WHILE IN USERNAME INPUT
	var thisObject = this;
	dojo.connect(this.username, "onKeyPress", function(event){
		var key = event.keyCode;

		// STOP EVENT BUBBLING
		event.stopPropagation();   
	
		// JUMP TO PASSWORD INPUT IF 'RETURN' KEY PRESSED
		if ( key == 13 )
		{
			thisObject.password.focus();
		}
	});

	// DO LOGIN IF 'RETURN' KEY PRESSED WHILE IN PASSWORD INPUT
	var thisObject = this;
	dojo.connect(this.password, "onKeyPress", function(event) {
		var key = event.keyCode;

		// STOP EVENT BUBBLING
		event.stopPropagation();   

		// LOGIN IF 'RETURN' KEY PRESSED
		if ( key == 13 )
		{
			thisObject.login();
		}

		// QUIT LOGIN WINDOW IF 'ESCAPE' KEY IS PRESSED
		if (key == dojo.keys.ESCAPE)
		{
			// FADE OUT LOGIN WINDOW
			dojo.fadeOut({ node: "loginDialogue", duration: 500 }).play();
			thisObject.loginDialogue.hide();
		}
	});	
},
setProgressBar : function () {
	this.hideProgressBar();
},
show : function () {
	console.log("Login.show    plugins.login.Login.show()");

	// SET THIS.LOGGING TO FALSE
	this.logging = false;
	
	// RESET STYLE TO DEFAULT
	dojo.removeClass(this.message, "error");
	dojo.removeClass(this.message, "accepted");

	// ADD CLASS
	dojo.addClass(this.loginDialogue.domNode, "login");

	// SET DEFAULT CSS CLASSES
	dojo.removeClass(this.message, "error");
	dojo.removeClass(this.message, "accepted");

	if ( this.loginDialogue == null ) {
		console.log("Login.show    this.loginDialogue == null. Returning.");
		return;
	}
	
	// SHOW INPUTS
	this.showInputs();
	
	// SET MESSAGE
	this.message.innerHTML = this.loginMessage;

	console.log("Login.show    DOING this.loginDialogue.show()");
	this.loginDialogue.show();
},
hide : function () {
// RESET STYLES TO DEFAULT AND HIDE DIALOGUE
	//console.log("Login.hide     plugins.login.Login.hide()");

	// IMMEDIATE HIDE
	//console.log("Login.hide    Doing dojo.style(this.domNode, opacity, 0)");
	dojo.style(this.domNode, "opacity", 0);
	
	//console.log("Login.hide    HIDE DIALOGUE");
	this.loginDialogue.hide();
	
	//console.log("Login.hide    RESETTING CSS to default");
	dojo.removeClass(this.message, "error");
	dojo.removeClass(this.message, "accepted");
	dojo.removeClass(this.message, "loading");
	
	//console.log("Login.hide    RESETTING this.message to default");
	this.message.innerHTML = "Loaded";
},
login : function () {
// AUTHENTICATE USERNAME AND PASSWORD
	console.log("Login.login     this.logging: " + this.logging);
	
	if( this.logging ) {
		console.log("Login.login     Returning.");
		return;
	}

	console.log("Login.login    Setting this.logging to TRUE");
	this.logging = true;

	var username = this.username.get('value');
	var password = this.password.get('value');
	
	if ( password == null || password == '' )	return;
	
	// SET LOGIN STYLE AND PROGRESS BAR
	this.setLoginStyle();

	// SET SESSION ID AND USER NAME TO NULL	
	Agua.cookie("sessionid", null); 
	Agua.cookie("username", null); 
	
	// CREATE JSON QUERY
	var query 			= 	{};
	query.sourceid		=	this.id;
	query.callback		=	"handleResponse",
	query.username 		= 	username;
	query.password 		= 	password;
	query.mode 			= 	"submitLogin";
	query.module 		= 	"Agua::Workflow";
	
	console.log("Login.login     query: " + dojo.toJson(query));

	console.log("Login.login    BEFORE Agua.exchange.send(query)");
	Agua.exchange.send(query);
	console.log("Login.login    Agua.exchange.send(query)");
},
handleResponse : function (response) {
	console.group("Login-" + this.id + "    handleResponse");
	console.log("Login.login    response: " + dojo.toJson(response));

	if ( response.error ) {
		// SET this.logging TO FALSE
		console.log("Login.login    Error. Setting this.logging to FALSE");
		this.logging = false;

		// SHOW ERROR STATUS ON LOGIN BUTTON
		dojo.addClass(this.message, "error");
		this.message.innerHTML = "Invalid username and password";

		// SHOW LOGIN INPUTS
		this.showInputs();
	}
	else {
		this.handleLogin(response);
	}

	console.groupEnd();
},
setLoginStyle : function () {
	// HIDE INPUTS
	this.hideInputs();
	
	// CHANGE MESSAGE
	dojo.removeClass(this.message, "error");
	dojo.removeClass(this.message, "accepted");
	this.message.innerHTML = "Authenticating...";
	
	console.log("Login.setLoginStyle    Doing progress bar removeClass 'inactive'"); 
    console.dir({login:this});       
    console.dir({progressBar:this.progressBar});       
},
showProgressBar : function () {	
	console.log("Login.showProgess    Doing progress bar removeClass 'inactive'");
    dojo.removeClass(this.progressBar.domNode, "inactive");
	this.message.innerHTML = "Loading Agua...";
},
hideProgressBar : function () {
	console.log("Login.hideProgess    Doing progress bar addClass 'inactive'");
    dojo.addClass(this.progressBar.domNode, "inactive");
	this.progressMessage.innerHTML = '';

	console.log("Login.hideProgess    END");
},
showInputs : function () {	
	console.log("Login.showInputs    DOING dojo.addClass(this.xxxRow, 'hidden')");
	dojo.removeClass(this.nameRow, "hidden");
	dojo.removeClass(this.passwordRow, "hidden");
	dojo.removeClass(this.buttonRow, "hidden");

	dojo.removeClass(this.message, "loading");
},
hideInputs : function () {
	console.log("Login.hideInputs    DOING dojo.removeClass(this.xxxRow, 'hidden')");
	dojo.addClass(this.nameRow, "hidden");
	dojo.addClass(this.passwordRow, "hidden");
	dojo.addClass(this.buttonRow, "hidden");
},
setLogoutStyle : function () {
	console.log("Logout.setLogoutStyle    Getting ");
	
	// RESET LOGIN DIALOGUE
	this.message.innerHTML = this.loginMessage;
	dojo.removeClass(this.message, "error");
	dojo.removeClass(this.message, "accepted");

	// RESET LOGIN TITLE
	this.statusBar.launcher.innerHTML = '';
	this.statusBar.launcher.title = 'Log In';
},
setLoading : function () {
	dojo.addClass(this.message, "loading");
	this.message.innerHTML = "Loading...";
},
handleLogin : function (response) {
	console.log("Login.handleLogin    response: " + dojo.toJson(response));
	console.log("Login.handleLogin    response.token " + response.token);
	console.log("Login.handleLogin    Agua.token " + Agua.token);
	console.log("Login.handleLogin    response.sendtype " + response.sendtype);

// DEBUG COMMENT - UNCOMMENT AFTER	
	//if ( response.token != Agua.token ) {
	//	console.log("Login.handleLogin    response.token " + response.token + " != Agua.token " + Agua.token + ". Returning");
	//	return;
	//}
	
	if ( response.sendtype != "response" ) {
		console.log("Login.handleLogin    response.sendtype not response 'response': " + response.sendtype + ". Returning");
		return;
	}

	// SHOW PROGRESS BAR
	this.showProgressBar();
	
	// REMOVE PASSWORD
	this.password.set('value', '');

	// SHOW ERROR IF PRESENT AS response.error
	if ( response.error != null && response.error != "" )
	{
		console.log("Login.handleLogin    Login error: " + response.error);

		console.log("Login.handleLogin    DOING this.showInputs()");
		this.showInputs();
		
		// SHOW ERROR STATUS ON LOGIN BUTTON
		dojo.addClass(this.message, "error");
		this.message.innerHTML = response.error;
	}
	
	// IF NO ERROR, PROCESS LOGIN
	else {
		console.log("Login.handleLogin    Successful login");
		console.log("Login.handleLogin    Successful Agua");
		console.dir({Agua:Agua});
		console.log("Login.handleLogin    response: " + dojo.toJson(response));

		// SET sessionid AND username IN DOJO COOKIE
		// THE COOKIE WILL EXPIRE AT THE END OF THE SESSION
		Agua.cookie("sessionid", response.data.sessionid);
		Agua.cookie("username", response.username);

		console.log("Login.handleLogin    username: " + response.username);
		console.log("Login.handleLogin    sessionid: " + response.sessionid);
		
		// SHOW 'Accepted' IN GREEN
		dojo.removeClass(this.message, "error");
		dojo.addClass(this.message, "accepted");
		this.message.innerHTML = "Accepted";

		var thisObject;
		setTimeout( function(thisObj){
			console.log("Login.handleLogin    setTimeout    Setting message to 'Loading Agua'");
			thisObj.setLoading();
		}, 1000, this);

		// CHANGE LOGIN STATUS BAR TO 'username' AND 'Log Out'
		this.statusBar.username.innerHTML = "<span class='label'></span> " + response.username;
		
		// SET LAUNCHER TITLE TO "Log Out"
		this.statusBar.launcher.title = "Log Out";

        // REMOVE login FROM LAUNCHER CSS CLASS
        dojo.removeClass(this.statusBar.launcher, "login");
		
		// REMOVE EXISTING 'login' LISTENER AND CREATE NEW 'logout' LISTENER
		dojo.disconnect(this.statusBar.launcher.listener);
		var listener = dojo.connect(this.statusBar.launcher, "onclick", this, "logout");
		this.statusBar.launcher.listener = listener;

		//// INITIALISE PLUGINS
		console.log("Login.handleLogin    DOING setTimeout( Agua.startPlugins(), 100)");
		
		setTimeout( function(thisObj){
			Agua.loadData();

			console.log("Login.handleLogin    AFTER Agua.startPlugins(). DOING this.hideProgressBar()");
			thisObj.hideProgressBar();
			
			console.log("Login.handleLogin    AFTER Agua.startPlugins(). AFTER this.hideProgressBar()");
			
		}, 100, this);

		console.log("Login.login    Setting this.logging to FALSE");
		this.logging = false;
		
		// FADE OUT LOGIN WINDOW
		// SET this.logging TO FALSE
		setTimeout( function(thisObj){
			dojo.fadeOut({ node: thisObj.loginDialogue.domNode, duration: 10 }).play();
			thisObj.hide();
			thisObj.logging = false;
			},
			100,
			this
		);
	}					
},
logout : function (e) {
	// SET COOKIE sessionid TO NULL
	Agua.cookie('sessionid', null);
	Agua.cookie('username', null);

	// SET STYLE
	this.setLogoutStyle();
	
	// CREATE NEW LISTENER
	dojo.disconnect(this.statusBar.launcher.listener);
	var listener = dojo.connect(this.statusBar.launcher, "onclick", this, "show");
	this.statusBar.launcher.listener = listener;

    // ADD login TO LAUNCHER CSS CLASS
    dojo.addClass(this.statusBar.launcher, "login");

    // SET LAUNCHER TITLE TO "Log In"
	this.statusBar.launcher.title = "Log In";

	// CLEAR TOOLBAR, PANES AND USER DATA
	Agua.doLogout();
}



}); //	end declare

});	//	end define
