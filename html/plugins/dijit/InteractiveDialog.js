/* AN INTERACTIVE INPUT DIALOG
  
	INTERACTIVELY RUN 'Enter' CALLBACK UNTIL CLOSED BY CALLBACK.

	UNLIKE IT'S PARENT CLASS inputDialog, interactiveDialog DOES

	NOT IMMEDIATELY DISAPPEAR AFTER 'Enter' HAS BEEN CLICKED.

	RATHER, IT HANGS AROUND UNTIL THE enterCallback METHOD CLOSES IT.
*/

console.log("Loading plugins/dijit/InteractiveDialog");

define("plugins/dijit/InteractiveDialog", [
	"dojo/_base/declare",
	"plugins/dijit/InputDialog"
],

function (
	declare,
	InputDialog
) {

/////}}}}}

return declare("plugins/dijit/InteractiveDialog",
	[ InputDialog ], {

//////}}

// SHOW THE DIALOGUE
show: function () {
	this.dialog.show();	
},
// HIDE THE DIALOGUE
hide: function () {
	this.dialog.hide();
},
doEnter : function(type) {
	console.log("InteractiveDialog.doEnter    plugins.dijit.InteractiveDialog.doEnter()");
	
	console.log("InteractiveDialog.doEnter    Doing this.dialog.hide()");
	this.dialog.hide();

	var input = '';
	if ( this.inputNode != null ) input = this.inputNode.value;
	var checked = false;
	if ( this.checkbox != null ) checked = this.checkbox.checked;
	if ( checked == true ) checked = 1;
	else checked = 0;
	
	console.log("InteractiveDialog.doEnter    input: " + input);		
	console.log("InteractiveDialog.doEnter    checked: " + checked);

	// DO CALLBACK
	this.dialog.enterCallback(input, checked, this);		
},
// RUN CANCEL CALLBACK IF 'CANCEL' CLICKED
doCancel : function() {
	console.log("InteractiveDialog.doCancel    plugins.dijit.InteractiveDialog.doCancel()");
	this.dialog.hide();
	this.dialog.cancelCallback();
},
close : function () {
	// REMOVE INPUT AND HIDE
	this.dialog.hide();
	this.inputNode.value = '';
}


}); //	end declare

});	//	end define
