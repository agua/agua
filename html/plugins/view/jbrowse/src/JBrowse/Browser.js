console.log("plugins.view.jbrowse.src.JBrowse.Browser    LOADING");

/**
 * Construct a new Browser object.
 * @class This class is the main interface between JBrowse and embedders
 * @constructor
 * @param params an object with the following properties:<br>
 * <ul>
 * <li><code>config</code> - list of objects with "url" property that points to a config JSON file</li>
 * <li><code>containerID</code> - ID of the HTML element that contains the browser</li>
 * <li><code>refSeqs</code> - object with "url" property that is the URL to list of reference sequence information items</li>
 * <li><code>browserRoot</code> - (optional) URL prefix for the browser code</li>
 * <li><code>tracks</code> - (optional) comma-delimited string containing initial list of tracks to view</li>
 * <li><code>location</code> - (optional) string describing the initial location</li>
 * <li><code>defaultTracks</code> - (optional) comma-delimited string containing initial list of tracks to view if there are no cookies and no "tracks" parameter</li>
 * <li><code>defaultLocation</code> - (optional) string describing the initial location if there are no cookies and no "location" parameter</li>
 * <li><code>show_nav</code> - (optional) string describing the on/off state of navigation box</li>
 * <li><code>show_tracklist</code> - (optional) string describing the on/off state of track bar</li>
 * <li><code>show_overview</code> - (optional) string describing the on/off state of overview</li>
 * </ul>
 */

var _gaq = _gaq || []; // global task queue for Google Analytics

define( "JBrowse/Browser", [
	'dojo/_base/declare',
	'dojo/_base/lang',
	'dojo/on',
	'dojo/keys',
	'dojo/Deferred',
	'dojo/DeferredList',
	'dojo/topic',
	'dojo/aspect',
	'JBrowse/has',
	'dojo/_base/array',
	'dijit/layout/ContentPane',
	'dijit/layout/BorderContainer',
	'plugins/dojox/layout/ExpandoPane',
	'dijit/Dialog',
	'dijit/form/ComboBox',
	'dijit/form/Button',
	'dijit/form/Select',
	'dijit/form/DropDownButton',
	'dijit/DropDownMenu',
	'dijit/MenuItem',
	'dijit/CheckedMenuItem',
	'JBrowse/Util',
	'JBrowse/Store/LazyTrie',
	'JBrowse/Store/Names/LazyTrieDojoData',
	'dojo/store/DataStore',
	'JBrowse/Store/Names/Hash',
	'JBrowse/GenomeView',
	'JBrowse/TouchScreenSupport',
	'JBrowse/ConfigManager',
	'JBrowse/View/InfoDialog',
	'JBrowse/View/FileDialog',
	'JBrowse/Model/Location',
	'JBrowse/View/LocationChoiceDialog',
	'JBrowse/View/Dialog/SetHighlight',
	'JBrowse/View/Dialog/QuickHelp',
	'dijit/focus',
	'lazyload', // for dynamic CSS loading

	'dijit/_Widget',
	'dijit/_Templated',
	'plugins/core/Common',

	'dojo/domReady!'
],

function(
	declare,
	lang,
	on,
	keys,
	Deferred,
	DeferredList,
	topic,
	aspect,
	has,
	array,
	dijitContentPane,
	dijitBorderContainer,
	dojoxExpandoPane,
	dijitDialog,
	dijitComboBox,
	dijitButton,
	dijitSelectBox,
	dijitDropDownButton,
	dijitDropDownMenu,
	dijitMenuItem,
	dijitCheckedMenuItem,
	Util,
	LazyTrie,
	NamesLazyTrieDojoDataStore,
	DojoDataStore,
	NamesHashStore,
	GenomeView,
	Touch,
	ConfigManager,
	InfoDialog,
	FileDialog,
	Location,
	LocationChoiceDialog,
	SetHighlightDialog,
	HelpDialog,
	dijitFocus,
	LazyLoad,
	
	// ADDED
	_Widget,
	_Templated,
	Common
) {

return declare("JBrowse/Browser",
[ _Widget, _Templated, Common ], {

/////}}}}}}    

//Path to the template of this widget. 
templatePath: require.toUrl("plugins/view/templates/browser.html"),

// Calls dijit._Templated.widgetsInTemplate
widgetsInTemplate : true,

// CSS FILE FOR BUTTON STYLING
/* CHANGED */
cssFiles : [
//require.toUrl("plugins/view/css/genome.css"),
require.toUrl("plugins/view/jbrowse/main.css"),
require.toUrl("plugins/view/jbrowse/menubar.css"),
require.toUrl("dojox/layout/resources/ExpandoPane.css"),
],

// uniqueCounter : Integer
//      Obsolete?
uniqCounter : 0,

/////}}}}}}    
////}}}}}

constructor : function(args) {		

////}}}}}

	console.log("Browser.constructor	args:");
	console.dir({args:args});

////}}}}}
	
	// LOAD CSS
	this.loadCSS();
	
	// SET PARAMS FROM ARGS
	this.params 		= args;
	this.viewObject 	= args.viewObject;
	this.location 		= args.location;
	this.locationObject = args.locationObject;
	this.refSeqs 		= args.refSeqs;
	this.attachWidget 	= args.attachWidget;
},
postCreate : function() {
	this.startup();
},
startup : function () {
  	console.group("JBrowse.Browser-" + this.id + "    startup");
	console.log("Browser.startup	JBrowse/Browser.startup()");

	// SET UP THE ELEMENT OBJECTS AND THEIR VALUE FUNCTIONS
	this.inherited(arguments);

	// ADD THE PANE TO THE TAB CONTAINER
	this.attachWidget.addChild(this.mainTab);
	this.attachWidget.selectChild(this.mainTab);

	console.log("Browser.startup	this.viewObject: " + dojo.toJson(this.viewObject));

	// SET TITLE
	this.mainTab.set('title', this.viewObject.project + "." + this.viewObject.view); 

	// SET SPECIES AND BUILD
	this.topPane.titleNode.innerHTML = this.firstLetterUpperCase(this.viewObject.species) + " (" + this.viewObject.build + ")";

    // SET VERSION
    this.version = this.getVersion();

    // -----------------------------   
    // -----------------------------   
    // ORIGINAL STARTS HERE

    this.globalKeyboardShortcuts = {};

    this.config = this.copyParams(this.params);
	console.log("Browser.startup	this.config:");
    console.dir({this_config:this.config});
    
    // if we're in the unit tests, stop here and don't do any more initialization
    if( this.config.unitTestMode )
        return;

    if( ! this.config.baseUrl )
        this.config.baseUrl = Util.resolveUrl( window.location.href, '.' ) + '/data/';

    this.startTime = new Date();

    // CHANGED
    //this.container = dojo.byId( this.config.containerID );
    //this.container.onselectstart = function() { return false; };
    
    // start the initialization process
    var thisB = this;
    //dojo.addOnLoad( function() {

        console.log("Browser.startup    DOING thisB.loadConfig()");

        thisB.loadConfig().then( function() {
        
            console.log("Browser.startup    thisB.loadConfig().THEN");
            
            // initialize our highlight if one was set in the config
            if( thisB.config.initialHighlight )
                thisB.setHighlight( new Location( thisB.config.initialHighlight ) );
            
            console.log("Browser.startup    thisB.loadConfig().THEN    DOING thisB.loadNames()");
            thisB.loadNames();
            
            console.log("Browser.startup    thisB.loadConfig().THEN    DOING thisB.initPlugins()");
            thisB.initPlugins().then( function() {
            
                console.log("Browser.startup    thisB.initPlugins().THEN");

                thisB.loadUserCSS().then( function() {
                
                    console.log("Browser.startup    thisB.loadUserCSS.THEN()");
                    
                    thisB.initTrackMetadata();
                    thisB.loadRefSeqs().then( function() {
                    
                        console.log("Browser.startup    thisB.loadRefSeqs.THEN()");
                       
                       // figure out our initial location
                       var initialLocString = thisB._initialLocation();
                       var initialLoc = Util.parseLocString( initialLocString );
                       this.refSeq = initialLoc && initialLoc.ref || this.refSeq;
                       
                       thisB.initView().then( function() {
                       
							console.log("Browser.startup    thisB.initView.THEN()");
						   
							console.log("Browser.startup    DOING Touch.loadTouch()");
	                        Touch.loadTouch(); // init touch device support
							console.log("Browser.startup    AFTER Touch.loadTouch()");

							console.log("Browser.startup    initialLocString: " + initialLocString);

							if( initialLocString ) {
								console.log("Browser.startup    DOING this.navigateTo(initialLocString)");
								thisB.navigateTo( initialLocString );
								console.log("Browser.startup    AFTER this.navigateTo(initialLocString)");
							}
						   
                           // figure out what initial track list we will use:
                           //    from a param passed to our instance, or from a cookie, or
                           //    the passed defaults, or the last-resort default of "DNA"?
                           var origTracklist =
                                  thisB.config.forceTracks
                               || thisB.cookie( "tracks" )
                               || thisB.config.defaultTracks
                               || "DNA";
                           
						   console.log("Browser.startup    origTracklist: " + origTracklist);
						   
						   console.log("Browser.startup    DOING this.showtracks(origTracklist)");
                           thisB.showTracks( origTracklist );

                           thisB.passMilestone( 'completely initialized', { success: true } );

						   // ENSURE TRACKS ARE DISPLAYED
						   var thisObj = thisB;
							setTimeout(function(thisObj) {
								thisB.centerPane.resize();
							},
							1500,
							thisObj)

                       });
                       thisB.reportUsageStats();
                    });
                });
            });
            
            console.log("Browser.startup    AFTER thisB.initPlugins()");

		  	console.log("JBrowse.Browser-" + this.id + "    startup    END");
		  	console.groupEnd("JBrowse.Browser-" + this.id + "    startup");
        });

    //});
    
    console.log("Browser.startup    END");

},
copyParams : function (params) {
    
    var copy = {};
    for ( var key in params ) {

        //console.log("Browser.copyParams    typeof params[" + key + "]: " + typeof params[key]);

        if ( params[key] && params[key].toString().match(/^\[Widget/) ) {

            //console.log("Browser.copyParams    Skipping key '" + key + "': " + params[key].toString());

            continue;
        }
        copy[key]   =   params[key];
    }
    
    return copy;
},

_initialLocation : function() {
    var oldLocMap = dojo.fromJson( this.cookie('location') ) || {};
    if( this.config.location ) {
        return this.config.location;
    } else if( oldLocMap[this.refSeq.name] ) {
        return oldLocMap[this.refSeq.name].l || oldLocMap[this.refSeq.name];
    } else if( this.config.defaultLocation ){
        return this.config.defaultLocation;
    } else {
        return Util.assembleLocString({
                                          ref:   this.refSeq.name,
                                          start: 0.4 * ( this.refSeq.start + this.refSeq.end ),
                                          end:   0.6 * ( this.refSeq.start + this.refSeq.end )
                                      });
    }
},

// CHANGED
/* version : function () {
     when a build is put together, the build system assigns a string
     to the variable below.
    var BUILD_SYSTEM_JBROWSE_VERSION = "1.9.8";
    return BUILD_SYSTEM_JBROWSE_VERSION || 'development';
} .call();
*/

getVersion : function() {
    // when a build is put together, the build system assigns a string
    // to the variable below.
	
    var BUILD_SYSTEM_JBROWSE_VERSION = "1.9.8";
    return BUILD_SYSTEM_JBROWSE_VERSION || 'development';
},

/**
 * Get a plugin, if it is present.  Note that, if plugin
 * initialization is not yet complete, it may be a while before the
 * callback is called.
 *
 * Callback is called with one parameter, the desired plugin object,
 * or undefined if it does not exist.
 */

getPlugin : function( name, callback ) {
    this.afterMilestone( 'initPlugins', dojo.hitch( this, function() {
        callback( this.plugins[name] );
    }));
},

/**
 * Load and instantiate any plugins defined in the configuration.
 */

initPlugins : function() {
    console.log("Browser.initPlugins");

    return this._milestoneFunction( 'initPlugins', function( deferred ) {

        this.plugins = {};
        var plugins = this.config.plugins || [];
        console.log("Browser.initPlugins    plugins: " + dojo.toJson(plugins));


        if( ! plugins ) {
            deferred.resolve({success: true});
            return;
        }

        // coerce plugins to array of objects
        plugins = array.map( lang.isArray( plugins ) ? plugins : [plugins], function( p ) {
            return typeof p == 'object' ? p : { 'name': p };
        });

        // set default locations for each plugin
        array.forEach( plugins, function(p) {
            if( !( 'location' in p ))
                p.location = 'plugins/'+p.name;

            // figure out js path
            if( !( 'js' in p ))
                p.js = p.location+"/js"; //URL resolution for this is taken care of by the JS loader
            if( p.js.charAt(0) != '/' && ! /^https?:/i.test( p.js ) )
                p.js = '../'+p.js;

            // figure out css path
            if( !( 'css' in p ))
                p.css = p.location+"/css";
        },this);

        var pluginDeferreds = array.map( plugins, function(p) {
            return new Deferred();
        });

        // fire the "all plugins done" deferred when all of the plugins are done loading
        (new DeferredList( pluginDeferreds ))
            .then( function() { deferred.resolve({success: true}); });

        require( {
                     packages: array.map( plugins, function(p) {
                                              return {
                                                  name: p.name,
                                                  location: p.js
                                              };
                                          }, this )
                 },
                 array.map( plugins, function(p) { return p.name; } ),
                 dojo.hitch( this, function() {
                     array.forEach( arguments, function( pluginClass, i ) {
                             var plugin = plugins[i];
                             var thisPluginDone = pluginDeferreds[i];
                             if( typeof pluginClass == 'string' ) {
                                 console.error("could not load plugin "+plugin.name+": "+pluginClass);
                             } else {
                                 // make the plugin's arguments out of
                                 // its little obj in 'plugins', and
                                 // also anything in the top-level
                                 // conf under its plugin name
                                 var args = dojo.mixin(
                                     dojo.clone( plugins[i] ),
                                     { config: this.config[ plugin.name ]||{} });
                                 args.browser = this;
                                 args = dojo.mixin( args, { browser: this } );

                                 // load its css
                                 var cssLoaded = this._loadCSS(
                                     {url: this.resolveUrl( plugin.css+'/main.css' ) }
                                 );
                                 cssLoaded.then( function() {
                                     thisPluginDone.resolve({success:true});
                                 });

                                 // give the plugin access to the CSS
                                 // promise so it can know when its
                                 // CSS is ready
                                 args.cssLoaded = cssLoaded;

                                 // instantiate the plugin
                                 this.plugins[ plugin.name ] = new pluginClass( args );
                             }
                         }, this );
                  }));
    });

},
/**
 * Resolve a URL relative to the browserRoot.
 */
resolveUrl : function( url ) {
    var browserRoot = this.config.browserRoot || "";
    if( browserRoot && browserRoot.charAt( browserRoot.length - 1 ) != '/' )
        browserRoot += '/';

    return Util.resolveUrl( browserRoot, url );
},
/**
 * Displays links to configuration help in the main window.  Called
 * when the main browser cannot run at all, due to configuration
 * errors or whatever.
 */
fatalError : function( error ) {
    console.log("Browser.fatalError    caller: " + this.fatalError.caller.nom);
    console.log("Browser.fatalError    error: ");
	console.dir({error:error});
	
    if( error ) {
        error = error+'';
        if( ! /\.$/.exec(error) )
            error = error + '.';
    }
	
    if( ! this.hasFatalErrors ) {
        //var container =
			// CHANGED
            // dojo.byId(this.config.containerID || 'GenomeBrowser')
//			this.centerPane.containerNode
//
//            || document.body;
//        container.innerHTML = ''
//            + '<div class="fatal_error">'
//            + '  <h1>Congratulations, JBrowse is on the web!</h1>'
//            + "  <p>However, JBrowse could not start, either because it has not yet been configured"
//            + "     and loaded with data, or because of an error.</p>"
//            + "  <p style=\"font-size: 110%; font-weight: bold\"><a title=\"View the tutorial\" href=\"docs/tutorial/\">If this is your first time running JBrowse, click here to follow the Quick-start Tutorial to get up and running.</a></p>"
//            + "  <p>Otherwise, please refer to the following resources for help in getting JBrowse up and running.</p>"
//            + '  <ul><li><a target="_blank" href="docs/tutorial/">Quick-start tutorial</a></li>'
//            + '      <li><a target="_blank" href="http://gmod.org/wiki/JBrowse">JBrowse wiki</a></li>'
//            + '      <li><a target="_blank" href="docs/config.html">Configuration reference</a></li>'
//            + '      <li><a target="_blank" href="docs/featureglyphs.html">Feature glyph reference</a></li>'
//            + '  </ul>'
//
//            + '  <div id="fatal_error_list" class="errors"> <h2>Error message(s):</h2>'
//            + ( error ? '<div class="error"> '+error+'</div>' : '' )
//            + '  </div>'
//            + '</div>'
//            ;
        this.hasFatalErrors = true;
    } else {
        var errors_div = dojo.byId('fatal_error_list') || document.body;
        dojo.create('div', { className: 'error', innerHTML: error+'' }, errors_div );
    }

		// CHANGED
	this.parentWidget.loadError(error);
},
loadRefSeqs : function() {
    return this._milestoneFunction( 'loadRefSeqs', function( deferred ) {
        
        console.log("Browser.loadRefSeqs    DOING this._milestoneFunction('loadRefSeqs')");
        console.log("Browser.loadRefSeqs    this.config.refSeqs:");
        console.dir({this_config_refSeqs:this.config.refSeqs});
        
        // load our ref seqs
        if( typeof this.config.refSeqs == 'string' )
            this.config.refSeqs = { url: this.config.refSeqs };
        dojo.xhrGet(
            {
                url: this.config.refSeqs.url,
                handleAs: 'json',
                load: dojo.hitch( this, function(o) {
                    this.addRefseqs( o );
                    deferred.resolve({success:true});
                }),
                error: dojo.hitch( this, function(e) {
                    this.fatalError('Failed to load reference sequence info: '+e);
                    deferred.resolve({ success: false, error: e });
                })
            });
    });
},
/**
 * Event that fires when the reference sequences have been loaded.
 */
onRefSeqsLoaded : function() {},
loadUserCSS : function() {
    return this._milestoneFunction( 'loadUserCSS', function( deferred ) {
        if( this.config.css && ! lang.isArray( this.config.css ) )
            this.config.css = [ this.config.css ];

        var css = this.config.css || [];
        if( ! css.length ) {
            deferred.resolve({success:true});
            return;
        }

        var that = this;
        var cssDeferreds = array.map( css, function( css ) {
            return that._loadCSS( css );
        });

        new DeferredList(cssDeferreds)
            .then( function() { deferred.resolve({success:true}); } );
   });
},
_loadCSS : function( css ) {
    var deferred = new Deferred();
    if( typeof css == 'string' ) {
        // if it has '{' in it, it probably is not a URL, but is a string of CSS statements
        if( css.indexOf('{') > -1 ) {
            dojo.create('style', { "data-from": 'JBrowse Config', type: 'text/css', innerHTML: css }, document.head );
            deferred.resolve(true);
        }
        // otherwise, it must be a URL
        else {
            css = { url: css };
        }
    }
    if( typeof css == 'object' ) {
        LazyLoad.css( css.url, function() { deferred.resolve(true); } );
    }
    return deferred;
},
/**
 * Load our name index.
 */
loadNames : function() {
    console.log("Browser.loadNames");
    
    return this._milestoneFunction( 'loadNames', function( deferred ) {

        console.log("Browser.loadNames    DOING this._milestoneFunction('loadNames')");

        var conf = dojo.mixin( dojo.clone( this.config.names || {} ),
                               this.config.autocomplete || {} );
        if( ! conf.url )
            conf.url = this.config.nameUrl || 'data/names/';

        if( conf.baseUrl )
            conf.url = Util.resolveUrl( conf.baseUrl, conf.url );

        if( conf.type == 'Hash' )
            this.nameStore = new NamesHashStore( dojo.mixin({ browser: this }, conf) );
        else
            // wrap the older LazyTrieDojoDataStore with
            // dojo.store.DataStore to conform with the dojo/store API
            this.nameStore = new DojoDataStore({
                store: new NamesLazyTrieDojoDataStore({
                    browser: this,
                    namesTrie: new LazyTrie( conf.url, "lazy-{Chunk}.json"),
                    stopPrefixes: conf.stopPrefixes,
                    resultLimit:  conf.resultLimit || 15,
                    tooManyMatchesMessage: conf.tooManyMatchesMessage
                })
            });

        deferred.resolve({success: true});
    });
},
/**
 * Compare two reference sequence names, returning -1, 0, or 1
 * depending on the result.  Case insensitive, insensitive to the
 * presence or absence of prefixes like 'chr', 'chrom', 'ctg',
 * 'contig', 'scaffold', etc
 */
compareReferenceNames : function( a, b ) {
    return this.regularizeReferenceName(a).localeCompare( this.regularizeReferenceName( b ) );
},
regularizeReferenceName : function( refname ) {

    if( this.config.exactReferenceSequenceNames )
        return refname;

    refname = refname.toLowerCase()
                     .replace(/^chro?m?(osome)?/,'chr')
                     .replace(/^co?n?ti?g/,'ctg')
                     .replace(/^scaff?o?l?d?/,'scaffold')
                     .replace(/^([a-z]*)0+/,'$1')
                     .replace(/^(\d+)$/, 'chr$1' );

    return refname;
},
/* SUMMARY OF CHANGES FROM PROGRAMATIC TO MARKUP ELEMENTS
	CODE                TEMPLATE
	this.container      this.rightPane
	topPane             this.topPane
	contentWidget       this.contentWidget
	browserWidget       this.centerPane
	
	rightPane
		topPane
		menubar
			overview
				locationThumb
				navbox
	
	centerPane (viewElem) (dijit.layout.ContentPane)
		browserWidget	(dijit.layout.ContentPane)
		containerWidget	(dijit.layout.BorderContainer)
*/
initView : function() {

    console.log("Browser.initView    START");

    var thisObj = this;
    return this._milestoneFunction('initView', function( deferred ) {

        // CHANGED
        //set up top nav/overview pane and main GenomeView pane
        //dojo.addClass( this.container, "jbrowse"); // browser container has an overall .jbrowse class
        // browser.html TEMPLATE TOP PANE HAS CLASS jbrowse

        dojo.addClass( document.body, this.config.theme || "tundra"); //< tundra dijit theme

        // CHANGED
        // ALREADY CREATED topPane IN TEMPLATE
        //var topPane = dojo.create( 'div',{ style: {overflow: 'hidden'}}, this.container );
        var topPane = this.topPane;
        console.log("Browser.initiView    topPane: ");
        console.dir({topPane:topPane});
        
        var about = this.browserMeta();
        var aboutDialog = new InfoDialog(
            {
                title: 'About '+about.title,
                content: about.description,
                className: 'about-dialog'
            });

        // CHANGED
        // ALREADY CREATED menuBar IN TEMPLATE
        //// make our top menu bar
        //var menuBar = dojo.create(
        //    'div',
        //    {
        //        className: this.config.show_nav ? 'menuBar' : 'topLink'
        //    }
        //    );
        //
        // ( this.config.show_nav ? topPane : this.container ).appendChild( menuBar );
        var menuBar = this.menuBar;
        thisObj.menuBar = menuBar;
        
        // CHANGED
        // ALREADY CREATED overview IN TEMPLATE
        //var overview = dojo.create( 'div', { className: 'overview', id: 'overview' }, topPane );
        var overview = this.overview;
        this.overviewDiv = overview;
        // overview=0 hides the overview, but we still need it to exist
        if( ! this.config.show_overview )
            overview.style.cssText = "display: none";

        // CHANGED
        // ALREADY CREATED navbox IN TEMPLATE
        // SEE this.createNavBox
        //if( this.config.show_nav ) {
        //    this.navbox = this.createNavBox( topPane );
            this.createNavBox( topPane );
        
            if( this.config.datasets && ! this.config.dataset_id ) {
                console.warn("In JBrowse configuration, datasets specified, but dataset_id not set.  Dataset selector will not be shown.");
            }
            if( this.config.datasets && this.config.dataset_id ) {
                this.renderDatasetSelect( menuBar );
            } else {
                dojo.create('a', {
                                className: 'powered_by',
                                innerHTML: 'JBrowse',
                                onclick: dojo.hitch( aboutDialog, 'show' ),
                                title: 'powered by JBrowse'
                            }, menuBar );
            }

            // make the file menu
            this.addGlobalMenuItem( 'file',
                                    new dijitMenuItem(
                                        {
                                            label: 'Open',
                                            iconClass: 'dijitIconFolderOpen',
                                            onClick: dojo.hitch( this, 'openFileDialog' )
                                        })
                                  );
            this.renderGlobalMenu( 'file', {text: 'File'}, menuBar );


            // make the view menu
            this.addGlobalMenuItem( 'view', new dijitMenuItem({
                label: 'Set highlight',
                onClick: function() {
                    new SetHighlightDialog({
                            browser: thisObj,
                            setCallback: dojo.hitch( thisObj, 'setHighlightAndRedraw' )
                        }).show();
                }
            }));
            // make the menu item for clearing the current highlight
            this._highlightClearButton = new dijitMenuItem(
                {
                    label: 'Clear highlight',
                    onClick: dojo.hitch( this, function() {
                                             var h = this.getHighlight();
                                             if( h ) {
                                                 this.clearHighlight();
                                                 this.view.redrawRegion( h );
                                             }
                                         })
                });
            this._updateHighlightClearButton();  //< sets the label and disabled status
            // update it every time the highlight changes
            this.subscribe( '/jbrowse/v1/n/globalHighlightChanged', dojo.hitch( this, '_updateHighlightClearButton' ) );

            this.addGlobalMenuItem( 'view', this._highlightClearButton );
            this.renderGlobalMenu( 'view', {text: 'View'}, menuBar );


            // make the options menu
            this.renderGlobalMenu( 'options', { text: 'Options', title: 'configure JBrowse' }, menuBar );

        // CHANGED
        //}

        if( this.config.show_nav ) {
            // make the help menu
            this.addGlobalMenuItem( 'help',
                                    new dijitMenuItem(
                                        {
                                            label: 'About',
                                            //iconClass: 'dijitIconFolderOpen',
                                            onClick: dojo.hitch( aboutDialog, 'show' )
                                        })
                                  );

            function showHelp() {
                new HelpDialog( lang.mixin(thisObj.config.quickHelp || {}, { browser: thisObj } )).show();
            }
            this.setGlobalKeyboardShortcut( '?', showHelp );
            this.addGlobalMenuItem( 'help',
                                    new dijitMenuItem(
                                        {
                                            label: 'General',
                                            iconClass: 'jbrowseIconHelp',
                                            onClick: showHelp
                                        })
                                  );

            this.renderGlobalMenu( 'help', {}, menuBar );
        }

        if( this.config.show_nav && this.config.show_tracklist && this.config.show_overview )
            menuBar.appendChild( this.makeShareLink() );
        else
            menuBar.appendChild( this.makeFullViewLink() );


        // CHANGED
        // ALREADY CREATED viewElem IN TEMPLATE
        //this.viewElem = document.createElement("div");
        //this.viewElem.className = "dragWindow";
        //this.container.appendChild( this.viewElem);
        this.viewElem = this.centerPane.containerNode;
		
        // CHANGED
        // ALREADY CREATED containerWidget IN TEMPLATE
        //this.containerWidget = new dijitBorderContainer({
        //    liveSplitters: false,
        //    design: "sidebar",
        //    gutters: false
        //}, this.container);


        // CHANGED
        // NO NEED FOR contentWidget ???
        // var contentWidget =
        //    new dijitContentPane({region: "top"}, topPane);
        // var contentWidget = this.contentWidget;
		
        // hook up GenomeView
        this.view = this.viewElem.view =
            new GenomeView(this, this.viewElem, 250, this.refSeq, 1/200 );

		console.log("Browser.initView     this.view: ");
		console.dir({this_view:this.view});

        dojo.connect( this.view, "onFineMove",   this, "onFineMove"   );
        dojo.connect( this.view, "onCoarseMove", this, "onCoarseMove" );

        // CHANGED
        // ALREADY CREATED browserWidget IN TEMPLATE
        //this.browserWidget =
        //    new dijitContentPane({region: "center"}, this.viewElem);
        
        dojo.connect( this.browserWidget, "resize", this,      'onResize' );
        dojo.connect( this.browserWidget, "resize", this.view, 'onResize' );

        //connect events to update the URL in the location bar
        function updateLocationBar() {
			
			//console.log("Browser.initView    updateLocationBar    thisObj.view.visibleRegionLocString(): " + thisObj.view.visibleRegionLocString());
            var shareURL = thisObj.makeCurrentViewURL();
			//console.log("Browser.initView    updateLocationBar    shareURL: " + shareURL);
			
            if( thisObj.config.updateBrowserURL && window.history && window.history.replaceState )
                window.history.replaceState( {},"", shareURL );
            document.title = thisObj.view.visibleRegionLocString()+' JBrowse';
        };
        dojo.connect( this, "onCoarseMove",                     updateLocationBar );
        this.subscribe( '/jbrowse/v1/n/tracks/visibleChanged',  updateLocationBar );
        this.subscribe( '/jbrowse/v1/n/globalHighlightChanged', updateLocationBar );

        //set initial location
        this.afterMilestone( 'loadRefSeqs', dojo.hitch( this, function() {
            this.afterMilestone( 'initTrackMetadata', dojo.hitch( this, function() {

				console.log("Browser.initView    DOING this.createTrackList()");	

                this.createTrackList().then( dojo.hitch( this, function() {

					console.log("Browser.initView    this.createTrackList().THEN");	

                    this.containerWidget.startup();
                    this.onResize();
                    this.view.onResize();
                    
                    // make our global keyboard shortcut handler
                    on( document.body, 'keypress', dojo.hitch( this, 'globalKeyHandler' ));
                    
                    // configure our event routing
                    this._initEventRouting();
                    
                    // done with initView
                    deferred.resolve({ success: true });
               }));
            }));
        }));
    });
},
renderDatasetSelect : function( parent ) {
    var dsconfig = this.config.datasets || {};
    var datasetChoices = [];
    for( var id in dsconfig ) {
        datasetChoices.push( dojo.mixin({ id: id }, dsconfig[id] ) );
    }

    new dijitSelectBox(
        {
            name: 'dataset',
            className: 'dataset_select',
            value: this.config.dataset_id,
            options: array.map(
                datasetChoices,
                function( dataset ) {
                    return { label: dataset.name, value: dataset.id };
                }),
            onChange: dojo.hitch(this, function( dsID ) {
                                     var ds = (this.config.datasets||{})[dsID];
                                     if( ds )
                                         window.location = ds.url;
                                     return false;
                                 })
        }).placeAt( parent );
},
/**
 * Get object like { title: "title", description: "description", ... }
 * that contains metadata describing this browser.
 */
browserMeta : function() {
    var about = this.config.aboutThisBrowser || {};
    about.title = about.title || 'JBrowse';

    console.log("Browser.browserMeta    this.version: " + this.version);
    console.dir({this_version:this.version});

    var verstring = this.version && this.version.match(/^\d/)
        ? this.version : '(development version)';

    if( about.description ) {
        about.description += '<div class="powered_by">'
            + 'Powered by <a target="_blank" href="http://jbrowse.org">JBrowse '+verstring+'</a>.'
            + '</div>';
    }
    else {
        about.description = '<div class="default_about">'
            + '  <img class="logo" src="'+this.resolveUrl('img/JBrowseLogo_small.png')+'">'
            + '  <h1>JBrowse '+verstring+'</h1>'
            + '  <div class="tagline">A next-generation genome browser<br> built with JavaScript and HTML5.</div>'
            + '  <a class="mainsite" target="_blank" href="http://jbrowse.org">JBrowse website</a>'
            + '  <div class="gmod">JBrowse is a <a target="_blank" href="http://gmod.org">GMOD</a> project.</div>'
            + '  <div class="copyright">&copy; 2013 The Evolutionary Software Foundation</div>'
            + '</div>';
    }
    return about;
},
/**
 * Track type registry, used by GUI elements that need to offer
 * options regarding selecting track types.  Can register a track
 * type, and get the data structure describing what track types are
 * known.
 */
registerTrackType : function( args ) {

    var types = this.getTrackTypes();
    var typeName   = args.type;
    var defaultFor = args.defaultForStoreTypes || [];
    var humanLabel = args.label;

    // add it to known track types
    types.knownTrackTypes.push( typeName );

    // add its label
    if( args.label )
        types.trackTypeLabels[typeName] = args.label;

    // uniqify knownTrackTypes
    var seen = {};
    types.knownTrackTypes = array.filter( types.knownTrackTypes, function( type ) {
        var s = seen[type];
        seen[type] = true;
        return !s;
    });

    // set it as default for the indicated types, if any
    array.forEach( defaultFor, function( storeName ) {
        types.trackTypeDefaults[storeName] = typeName;
    });

    // store the whole structure in this object
    this._knownTrackTypes = types;
},
getTrackTypes : function() {
    console.log("Browser.getTrackTypes");
	
	// create the default types if necessary
    if( ! this._knownTrackTypes )
        this._knownTrackTypes = {
            // map of store type -> default track type to use for the store
            trackTypeDefaults: {
                'JBrowse/Store/SeqFeature/BAM'        : 'JBrowse/View/Track/Alignments2',
                'JBrowse/Store/SeqFeature/NCList'     : 'JBrowse/View/Track/HTMLFeatures',
                'JBrowse/Store/SeqFeature/BigWig'     : 'JBrowse/View/Track/Wiggle/XYPlot',
                'JBrowse/Store/Sequence/StaticChunked': 'JBrowse/View/Track/Sequence',
                'JBrowse/Store/SeqFeature/VCFTabix'   : 'JBrowse/View/Track/HTMLVariants'
            },

            knownTrackTypes: [
                'JBrowse/View/Track/Alignments',
                'JBrowse/View/Track/Alignments2',
                'JBrowse/View/Track/FeatureCoverage',
                'JBrowse/View/Track/SNPCoverage',
                'JBrowse/View/Track/HTMLFeatures',
                'JBrowse/View/Track/HTMLVariants',
                'JBrowse/View/Track/Wiggle/XYPlot',
                'JBrowse/View/Track/Wiggle/Density',
                'JBrowse/View/Track/Sequence'
            ],

            trackTypeLabels: {
            }
        };

    return this._knownTrackTypes;
},
openFileDialog : function() {
    new FileDialog({ browser: this })
        .show({
            openCallback: dojo.hitch( this, function( results ) {
				console.log("Browser.openFileDialog.openCallback    results:");
				console.dir({results:results});

                var confs = results.trackConfs || [];
                if( confs.length ) {

                    // tuck away each of the store configurations in
                    // our store configuration, and replace them with
                    // their names.
                    array.forEach( confs, function( conf ) {
                        var storeConf = conf.store;
                        if( storeConf && typeof storeConf == 'object' ) {
                            delete conf.store;
                            var name = this._addStoreConfig( storeConf.name, storeConf );
                            conf.store = name;
                        }
                    },this);

                    // send out a message about how the user wants to create the new tracks
                    this.publish( '/jbrowse/v1/v/tracks/new', confs );

                    // if requested, send out another message that the user wants to show them
                    if( results.trackDisposition == 'openImmediately' )
                        this.publish( '/jbrowse/v1/v/tracks/show', confs );
                }
            })
        });
},
addTracks : function( confs ) {
    // just register the track configurations right now
    this._addTrackConfigs( confs );
},
replaceTracks : function( confs ) {
    // just add-or-replace the track configurations
    this._replaceTrackConfigs( confs );
},
deleteTracks : function( confs ) {
    // de-register the track configurations
    this._deleteTrackConfigs( confs );
},
renderGlobalMenu : function( menuName, args, parent ) {
    var menu = this.makeGlobalMenu( menuName );
    if( menu ) {
        args = dojo.mixin(
            {
                className: menuName,
                innerHTML: '<span class="icon"></span> '+ ( args.text || Util.ucFirst(menuName)),
                dropDown: menu
            },
            args || {}
        );

        var menuButton = new dijitDropDownButton( args );
        dojo.addClass( menuButton.domNode, 'menu' );
        parent.appendChild( menuButton.domNode );
    }
},
makeGlobalMenu : function( menuName ) {
    var items = ( this._globalMenuItems || {} )[menuName] || [];
    if( ! items.length )
        return null;

    var menu = new dijitDropDownMenu({ leftClickToOpen: true });
    dojo.forEach( items, function( item ) {
        menu.addChild( item );
    });
    dojo.addClass( menu.domNode, 'globalMenu' );
    menu.startup();
    return menu;
},
addGlobalMenuItem : function( menuName, item ) {
    if( ! this._globalMenuItems )
        this._globalMenuItems = {};
    if( ! this._globalMenuItems[ menuName ] )
        this._globalMenuItems[ menuName ] = [];
    this._globalMenuItems[ menuName ].push( item );
},
/**
 * Initialize our message routing, subscribing to messages, forwarding
 * them around, and so forth.
 *
 * "v" (view)
 *   Requests from the user.  These go only to the browser, which is
 *   the central point forx deciding what to do about them.  This is
 *   usually just forwarding the command as one or more "c" messages.
 *
 * "c" (command)
 *   Commands from authority, like the Browser object.  These cause
 *   things to actually happen in the UI: things to be shown or
 *   hidden, actions taken, and so forth.
 *
 * "n" (notification)
 *   Notification that something just happened.
 *
 * @private
 */
_initEventRouting : function() {
    var that = this;

    that.subscribe('/jbrowse/v1/v/tracks/hide', function( trackConfigs ) {
        that.publish( '/jbrowse/v1/c/tracks/hide', trackConfigs );
    });
    that.subscribe('/jbrowse/v1/v/tracks/show', function( trackConfigs ) {
        that.addRecentlyUsedTracks( dojo.map(trackConfigs, function(c){ return c.label;}) );
        that.publish( '/jbrowse/v1/c/tracks/show', trackConfigs );
    });

    that.subscribe('/jbrowse/v1/v/tracks/new', function( trackConfigs ) {
        that.addTracks( trackConfigs );
        that.publish( '/jbrowse/v1/c/tracks/new', trackConfigs );
    });
    that.subscribe('/jbrowse/v1/v/tracks/replace', function( trackConfigs ) {
        that.replaceTracks( trackConfigs );
        that.publish( '/jbrowse/v1/c/tracks/replace', trackConfigs );
    });
    that.subscribe('/jbrowse/v1/v/tracks/delete', function( trackConfigs ) {
        that.deleteTracks( trackConfigs );
        that.publish( '/jbrowse/v1/c/tracks/delete', trackConfigs );
    });
},
/**
 * Reports some anonymous usage statistics about this browsing
 * instance.  Currently reports the number of tracks in the instance
 * and their type (feature, wiggle, etc), and the number of reference
 * sequences and their average length.
 */
reportUsageStats : function() {
    if( this.config.suppressUsageStatistics )
        return;

    var stats = this._calculateClientStats();
    this._reportGoogleUsageStats( stats );
    this._reportCustomUsageStats( stats );
},
// phones home to google analytics
_reportGoogleUsageStats : function( stats ) {
    _gaq.push.apply( _gaq, [
        ['_setAccount', 'UA-7115575-2'],
        ['_setDomainName', 'none'],
        ['_setAllowLinker', true],
        ['_setCustomVar', 1, 'tracks-count', stats['tracks-count'], 3 ],
        ['_setCustomVar', 2, 'refSeqs-count', stats['refSeqs-count'], 3 ],
        ['_setCustomVar', 3, 'refSeqs-avgLen', stats['refSeqs-avgLen'], 3 ],
        ['_setCustomVar', 4, 'jbrowse-version', stats['ver'], 3 ],
        ['_setCustomVar', 5, 'loadTime', stats['loadTime'], 3 ],
        ['_trackPageview']
    ]);

    var ga = document.createElement('script');
    ga.type = 'text/javascript';
    ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www')
             + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0];
    s.parentNode.insertBefore(ga, s);
},
// phones home to custom analytics at jbrowse.org
_reportCustomUsageStats : function(stats) {
    // phone home with a GET request made by a script tag
    dojo.create(
        'img',
        { style: {
              display: 'none'
          },
          src: 'http://jbrowse.org/analytics/clientReport?'
               + dojo.objectToQuery( stats )
        },
        document.body
    );
},
/**
 * Get a store object from the store registry, loading its code and
 * instantiating it if necessary.
 */
getStore : function( storeName, callback ) {
    if( !callback ) throw 'invalid arguments';

    var storeCache = this._storeCache || {};
    this._storeCache = storeCache;

    var storeRecord = storeCache[ storeName ];
    if( storeRecord ) {
        storeRecord.refCount++;
        callback( storeRecord.store );
        return;
    }

    var conf = this.config.stores[storeName];
    if( ! conf ) {
        console.warn( "store '"+storeName+"' not found" );
        callback( null );
        return;
    }

    var storeClassName = conf.type;
    if( ! storeClassName ) {
        console.warn( "store "+storeName+" has no type defined" );
        callback( null );
        return;
    }

    require( [ storeClassName ], dojo.hitch( this, function( storeClass ) {
                 var storeArgs = {};
                 dojo.mixin( storeArgs, conf );
                 dojo.mixin( storeArgs,
                             {
                                 config: conf,
                                 browser: this,
                                 refSeq: this.refSeq
                             });

                 var store = new storeClass( storeArgs );
                 this._storeCache[ storeName ] = { refCount: 1, store: store };
                 callback( store );
                 // release the callback because apparently require
                 // doesn't release this function
                 callback = undefined;
             }));
},
/**
 * Add a store configuration to the browser.  If name is falsy, will
 * autogenerate one.
 * @private
 */
_addStoreConfig : function( /**String*/ name, /**Object*/ storeConfig ) {
    name = name || 'addStore'+uniqCounter++;

    if( ! this.config.stores )
        this.config.stores = {};
    if( ! this._storeCache )
        this._storeCache = {};

    if( this.config.stores[name] || this._storeCache[name] ) {
        throw "store "+name+" already exists!";
    }

    this.config.stores[name] = storeConfig;
    return name;
},
clearStores : function() {
    this._storeCache = {};
},
/**
 * Notifies the browser that the given named store is no longer being
 * used by the calling component.  Decrements the store's reference
 * count, and if the store's reference count reaches zero, the store
 * object will be discarded, to be recreated again later if needed.
 */
// not actually being used yet
releaseStore : function( storeName ) {
    var storeRecord = this._storeCache[storeName];
    if( storeRecord && ! --storeRecord.refCount )
        delete this._storeCache[storeName];
},
_calculateClientStats : function() {

    var scn = screen || window.screen;

    // make a flat (i.e. non-nested) object for the stats, so that it
    // encodes compactly in the query string
    var date = new Date();
    var stats = {
        ver: this.version || 'dev',
        'refSeqs-count': this.refSeqOrder.length,
        'refSeqs-avgLen':
          ! this.refSeqOrder.length
            ? null


            // CHANGED
            //: dojof.reduce(
            : Util.dojof.reduce(

                dojo.map( this.refSeqOrder,
                          function(name) {
                              var ref = this.allRefs[name];
                              if( !ref )
                                  return 0;
                              return ref.end - ref.start;
                          },
                          this
                        ),
                '+'
            ),
        'tracks-count': this.config.tracks.length,

        // CHANGED
        //'plugins': dojof.keys( this.plugins ).sort().join(','),
        'plugins': Util.dojof.keys( this.plugins ).sort().join(','),
        
        // screen geometry
        'scn-h': scn ? scn.height : null,
        'scn-w': scn ? scn.width  : null,
        // window geometry
        'win-h':document.body.offsetHeight,
        'win-w': document.body.offsetWidth,
        // container geometry

		// CHANGED
		// MOVED this.container TO this.rightPane
        //'el-h': this.container.offsetHeight,
        //'el-w': this.container.offsetWidth,
        'el-h': this.rightPane.offsetHeight,
        'el-w': this.rightPane.offsetWidth,
		
        // time param to prevent caching
        t: date.getTime()/1000,

        // also get local time zone offset
        tzoffset: date.getTimezoneOffset(),

        loadTime: (date.getTime() - this.startTime)/1000
    };

    // count the number and types of tracks
    dojo.forEach( this.config.tracks, function(trackConfig) {
        var typeKey = 'track-types-'+ trackConfig.type || 'null';
        stats[ typeKey ] =
          ( stats[ typeKey ] || 0 ) + 1;
    });

    return stats;
},
publish : function() {
	//console.log("Browser.publish    this.config: ");
	//console.dir({this_config:this.config});
	//
	//console.log("Browser.publish    topic : ");
	//console.dir({topic :topic });
	//
	//console.log("Browser.publish    arguments : ");
	//console.dir({arguments :arguments });

    if( this.config.logMessages )
        console.log( arguments );

    return topic.publish.apply( topic, arguments );
},
subscribe : function() {
    return topic.subscribe.apply( topic, arguments );
},
onResize : function() {
    if( this.navbox )
        this.view.locationTrapHeight = dojo.marginBox( this.navbox ).h;
},
/**
 * Get the list of the most recently used tracks, stored for this user
 * in a cookie.
 * @returns {Array[Object]} as <code>[{ time: (integer), label: (track label)}]</code>
 */
getRecentlyUsedTracks : function() {
    return dojo.fromJson( this.cookie( 'recentTracks' ) || '[]' );
},
/**
 * Add the given list of tracks as being recently used.
 * @param trackLabels {Array[String]} array of track labels to add
 */
addRecentlyUsedTracks : function( trackLabels ) {
    var seen = {};
    var newRecent =
        Util.uniq(
            dojo.map( trackLabels, function(label) {
                          return {
                              label: label,
                              time: Math.round( new Date() / 1000 ) // secs since epoch
                          };
                      },this)
                .concat( dojo.fromJson( this.cookie('recentTracks'))  || [] ),
            function(entry) {
                return entry.label;
            }
        )
        // limit by default to 20 recent tracks
        .slice( 0, this.config.maxRecentTracks || 10 );

    // set the recentTracks cookie, good for one year
    this.cookie( 'recentTracks', newRecent, { expires: 365 } );

    return newRecent;
},
/**
 * Run a function that will eventually resolve the named Deferred
 * (milestone).
 * @param {String} name the name of the Deferred
 */
_milestoneFunction : function( /**String*/ name, func ) {

    console.log("Browser._milestoneFunction    name: " + name);
    
    var thisB = this;
    var args = Array.prototype.slice.call( arguments, 2 );

    var d = thisB._getDeferred( name );
    args.unshift( d );
    try {
        func.apply( thisB, args ) ;
    } catch(e) {
        console.error( e, e.stack );
        d.resolve({ success:false, error: e });
    }

    return d;
},
/**
 * Fetch or create a named Deferred, which is how milestones are implemented.
 */
_getDeferred : function( name ) {
    if( ! this._deferred )
        this._deferred = {};
    return this._deferred[name] = this._deferred[name] || new Deferred();
},
/**
 * Attach a callback to a milestone.
 */
afterMilestone : function( name, func ) {
    return this._getDeferred(name)
        .then( function() {
                   try {
                       func();
                   } catch( e ) {
                       console.error( ''+e, e.stack, e );
                   }
               });
},
/**
 * Indicate that we've reached a milestone in the initalization
 * process.  Will run all the callbacks associated with that
 * milestone.
 */
passMilestone : function( name, result ) {
    return this._getDeferred(name).resolve( result );
},
/**
 * Return true if we have reached the named milestone, false otherwise.
 */
reachedMilestone : function( name ) {
    return this._getDeferred(name).fired >= 0;
},
/**
 *  Load our configuration file(s) based on the parameters the
 *  constructor was passed.  Does not return until all files are
 *  loaded and merged in.
 *  @returns nothing meaningful
 */
loadConfig : function () {
    return this._milestoneFunction( 'loadConfig', function( deferred ) {

        console.log("Browser.loadConfig    DOING new.ConfigManager()");

        var c = new ConfigManager({ config: this.config, defaults: this._configDefaults(), browser: this });

        console.log("Browser.loadConfig    AFTER new.ConfigManager()");

        c.getFinalConfig( dojo.hitch(this, function( finishedConfig ) {
		        console.log("Browser.loadConfig    configManager.getFinalConfig    finishedConfig: ");
				console.dir({finishedConfig:finishedConfig});

                this.config = finishedConfig;
        
                console.log("Browser.loadConfig    this.config:");
                console.dir({this_config:this.config});

                // pass the tracks configurations through
                // addTrackConfigs so that it will be indexed and such
                var tracks = finishedConfig.tracks || [];
                delete finishedConfig.tracks;
                this._addTrackConfigs( tracks );
               
                // coerce some config keys to boolean
                dojo.forEach( ['show_tracklist','show_nav','show_overview'], function(v) {
                                  this.config[v] = this._coerceBoolean( this.config[v] );
                              },this);
               
               // set empty tracks array if we have none
               if( ! this.config.tracks )
                   this.config.tracks = [];
               
                deferred.resolve({success:true});
        }));


        console.log("Browser.loadConfig    END");

    });
},
/**
 * Add new track configurations.
 * @private
 */
_addTrackConfigs : function( /**Array*/ configs ) {
	console.log("Browser._addTrackConfigs    configs: ");
	console.dir({configs:configs});

    if( ! this.config.tracks )
        this.config.tracks = [];
    if( ! this.trackConfigsByName )
        this.trackConfigsByName = {};

    array.forEach( configs, function(conf){
        console.warn("Browser._addTrackConfigs    DOING track " + conf.label);

        // if( this.trackConfigsByName[ conf.label ] ) {
        //     console.warn("track with label "+conf.label+" already exists, skipping");
        //     return;
        // }

        this.trackConfigsByName[conf.label] = conf;
        this.config.tracks.push( conf );

    },this);

    return configs;
},
/**
 * Replace existing track configurations.
 * @private
 */
_replaceTrackConfigs : function( /**Array*/ newConfigs ) {
    if( ! this.trackConfigsByName )
        this.trackConfigsByName = {};

    array.forEach( newConfigs, function( conf ) {
        if( ! this.trackConfigsByName[ conf.label ] ) {
            console.warn("track with label "+conf.label+" does not exist yet.  creating a new one.");
        }

        this.trackConfigsByName[conf.label] =
                           dojo.mixin( this.trackConfigsByName[ conf.label ] || {}, conf );
   },this);
},
/**
 * Delete existing track configs.
 * @private
 */
_deleteTrackConfigs : function( configsToDelete ) {
    // remove from this.config.tracks
    this.config.tracks = array.filter( this.config.tracks || [], function( conf ) {
        return ! array.some( configsToDelete, function( toDelete ) {
            return toDelete.label == conf.label;
        });
    });

    // remove from trackConfigsByName
    array.forEach( configsToDelete, function( toDelete ) {
        if( ! this.trackConfigsByName[ toDelete.label ] ) {
            console.warn( "track "+toDelete.label+" does not exist, cannot delete" );
            return;
        }

        delete this.trackConfigsByName[ toDelete.label ];
    },this);
},
_configDefaults : function() {
    return {
        tracks: [],
        show_tracklist: true,
        show_nav: true,
        show_overview: true
    };
},
/**
 * Coerce a value of unknown type to a boolean, treating string 'true'
 * and 'false' as the values they indicate, and string numbers as
 * numbers.
 * @private
 */
_coerceBoolean : function(val) {
    if( typeof val == 'string' ) {
        val = val.toLowerCase();
        if( val == 'true' ) {
            return true;
        }
        else if( val == 'false' )
            return false;
        else
            return parseInt(val);
    }
    else if( typeof val == 'boolean' ) {
        return val;
    }
    else if( typeof val == 'number' ) {
        return !!val;
    }
    else {
        return true;
    }
},
/**
 * @param refSeqs {Array} array of refseq records to add to the browser
 */
addRefseqs : function( refSeqs ) {
    var allrefs = this.allRefs = this.allRefs || {};
    dojo.forEach( refSeqs, function(r) {
        this.allRefs[r.name] = r;
    },this);

    // generate refSeqOrder
    this.refSeqOrder =
        function() {
            var order;
            if( ! this.config.refSeqOrder ) {
                order = refSeqs;
            }
            else {
                order = refSeqs.slice(0);
                order.sort(
                    this.config.refSeqOrder == 'length'            ? function( a, b ) { return a.length - b.length;  }  :
                    this.config.refSeqOrder == 'length descending' ? function( a, b ) { return b.length - a.length;  }  :
                    this.config.refSeqOrder == 'name descending'   ? function( a, b ) { return b.name.localeCompare( a.name ); } :
                                                                     function( a, b ) { return a.name.localeCompare( b.name ); }
                );
            }
            return array.map( order, function( r ) {
                                  return r.name;
                              });
        }.call(this);

    this.refSeq = this.refSeq || this.allRefs[ this.refSeqOrder[0] ];
},
getCurrentRefSeq : function( name, callback ) {
    return this.refSeq || {};
},
getRefSeq : function( name, callback ) {
    if( typeof name != 'string' )
        name = this.refSeqOrder[0];

    callback( this.allRefs[ name ] );
},
/**
 * @private
 */
onFineMove : function(startbp, endbp) {

    if( this.locationTrap ) {
        var length = this.view.ref.end - this.view.ref.start;
        var trapLeft = Math.round((((startbp - this.view.ref.start) / length)
                                   * this.view.overviewBox.w) + this.view.overviewBox.l);
        var trapRight = Math.round((((endbp - this.view.ref.start) / length)
                                    * this.view.overviewBox.w) + this.view.overviewBox.l);
        dojo.style( this.locationTrap, {
                        width: (trapRight - trapLeft) + "px",
                        borderBottomWidth: this.view.locationTrapHeight + "px",
                        borderLeftWidth: trapLeft + "px",
                        borderRightWidth: (this.view.overviewBox.w - trapRight) + "px"
        });
    }
},
/**
 * Asynchronously initialize our track metadata.
 */
initTrackMetadata : function( callback ) {
    return this._milestoneFunction( 'initTrackMetadata', function( deferred ) {
        var metaDataSourceClasses = dojo.map(
                                    (this.config.trackMetadata||{}).sources || [],
                                    function( sourceDef ) {
                                        var url  = sourceDef.url || 'trackMeta.csv';
                                        var type = sourceDef.type || (
                                                /\.csv$/i.test(url)     ? 'csv'  :
                                                /\.js(on)?$/i.test(url) ? 'json' :
                                                'csv'
                                        );
                                        var storeClass = sourceDef['class']
                                            || { csv: 'dojox/data/CsvStore', json: 'dojox/data/JsonRestStore' }[type];
                                        if( !storeClass ) {
                                            console.error( "No store class found for type '"
                                                           +type+"', cannot load track metadata from URL "+url);
                                            return null;
                                        }
                                        return { class_: storeClass, url: url };
                                    });


        require( Array.prototype.concat.apply( ['JBrowse/Store/TrackMetaData'],
                                               dojo.map( metaDataSourceClasses, function(c) { return c.class_; } ) ),
                 dojo.hitch(this,function( MetaDataStore ) {
                     var mdStores = [];
                     for( var i = 1; i<arguments.length; i++ ) {
                         mdStores.push( new (arguments[i])({url: metaDataSourceClasses[i-1].url}) );
                     }

                     this.trackMetaDataStore =  new MetaDataStore(
                         dojo.mixin( dojo.clone(this.config.trackMetadata || {}), {
                                         trackConfigs: this.config.tracks,
                                         browser: this,
                                         metadataStores: mdStores
                                     })
                     );

                     deferred.resolve({success:true});
        }));
    });
},
/**
 * Asynchronously create the track list.
 * @private
 */
createTrackList : function() {
    return this._milestoneFunction('createTrack', function( deferred ) {

		console.log("Browser.createTrackList    DOING this._milestoneFunction('createTrack')");
		console.log("Browser.createTrackList    this.config:");
		console.dir({this_config:this.config});

        // find the tracklist class to use
        var tl_class = !this.config.show_tracklist           ? 'Null'                         :
                       (this.config.trackSelector||{}).type  ? this.config.trackSelector.type :
                                                               'Simple';

		console.log("Browser.createTrackList    tl_class: " + tl_class);
		console.log("Browser.createTrackList    this.config.tracks: ");
		console.dir({this_config_tracks:this.config.tracks});

		
        if( ! /\//.test( tl_class ) )
            tl_class = 'JBrowse/View/TrackList/'+tl_class;

        // load all the classes we need
        require( [ tl_class ],
                 dojo.hitch( this, function( trackListClass ) {
                     // instantiate the tracklist and the track metadata object
                     this.trackListView = new trackListClass(
                         dojo.mixin(
                             dojo.clone( this.config.trackSelector ) || {},
                             {
                                 trackConfigs: this.config.tracks,
                                 browser: this,
                                 trackMetaData: this.trackMetaDataStore
                             }
                         )
                     );

                     // bind the 't' key as a global keyboard shortcut
                     this.setGlobalKeyboardShortcut( 't', this.trackListView, 'toggle' );

                     // listen for track-visibility-changing messages from
                     // views and update our tracks cookie
                     this.subscribe( '/jbrowse/v1/n/tracks/visibleChanged', dojo.hitch( this, function() {
                         this.cookie( "tracks",
                                      this.view.visibleTrackNames().join(','),
                                      {expires: 60});
                     }));

                     deferred.resolve({ success: true });
        }));
    });
},
/**
 * @private
 */
onVisibleTracksChanged : function() {
},
/**
 * Like <code>navigateToLocation()</code>, except it attempts to display the given
 * location with a little bit of flanking sequence to each side, if
 * possible.
 */
showRegion : function( location ) {
    var flank   = Math.round( ( location.end - location.start ) * 0.2 );
    //go to location, with some flanking region
    this.navigateToLocation({ ref: location.ref,
                               start: location.start - flank,
                               end: location.end + flank
                             });

    // if the location has a track associated with it, show it
    if( location.tracks ) {
        this.showTracks( array.map( location.tracks, function( t ) { return t && (t.label || t.name) || t; } ));
    }
},
/**
 * navigate to a given location
 * @example
 * gb=dojo.byId("GenomeBrowser").genomeBrowser
 * gb.navigateTo("ctgA:100..200")
 * gb.navigateTo("f14")
 * @param loc can be either:<br>
 * &lt;chromosome&gt;:&lt;start&gt; .. &lt;end&gt;<br>
 * &lt;start&gt; .. &lt;end&gt;<br>
 * &lt;center base&gt;<br>
 * &lt;feature name/ID&gt;
 */
navigateTo : function(loc) {
        this.afterMilestone( 'initView', dojo.hitch( this, function() {
        // if it's a foo:123..456 location, go there
        var location = typeof loc == 'string' ? Util.parseLocString( loc ) :  loc;
        if( location ) {
            this.navigateToLocation( location );
        }
        // otherwise, if it's just a word, try to figure out what it is
        else {

            // is it just the name of one of our ref seqs?
            var ref = Util.matchRefSeqName( loc, this.allRefs );
            if( ref ) {
                // see if we have a stored location for this ref seq in a
                // cookie, and go there if we do
                var oldLoc;
                try {
                    oldLoc = Util.parseLocString(
                        dojo.fromJson(
                            this.cookie("location")
                        )[ref.name].l
                    );
                    oldLoc.ref = ref.name; // force the refseq name; older cookies don't have it
                } catch (x) {}
                if( oldLoc ) {
                    this.navigateToLocation( oldLoc );
                    return;
                } else {
                    // if we don't just go to the middle 80% of that refseq,
                    // based on range that can be viewed (start to end)
                    // rather than total length, in case start != 0 || end != length
                    // this.navigateToLocation({ref: ref.name, start: ref.end*0.1, end: ref.end*0.9 });
                    var visibleLength = ref.end - ref.start;
                    this.navigateToLocation({ref:   ref.name,
                                             start: ref.start + (visibleLength * 0.1),
                                             end:   ref.start + (visibleLength * 0.9) } );
                    return;
                }
            }

            // lastly, try to search our feature names for it
            this.searchNames( loc );
        }
    }));
},
// given an object like { ref: 'foo', start: 2, end: 100 }, set the
// browser's view to that location.  any of ref, start, or end may be
// missing, in which case the function will try set the view to
// something that seems intelligent
navigateToLocation : function( location ) {
    this.afterMilestone( 'initView', dojo.hitch( this, function() {
        // validate the ref seq we were passed
        var ref = location.ref ? Util.matchRefSeqName( location.ref, this.allRefs )
                               : this.refSeq;
        if( !ref )
            return;
        location.ref = ref.name;

        // clamp the start and end to the size of the ref seq
        location.start = Math.max( 0, location.start || 0 );
        location.end   = Math.max( location.start,
                                   Math.min( ref.end, location.end || ref.end )
                                 );

        // if it's the same sequence, just go there
        if( location.ref == this.refSeq.name) {
            this.view.setLocation( this.refSeq,
                                   location.start,
                                   location.end
                                 );
            this._updateLocationCookies( location );
        }
        // if different, we need to poke some other things before going there
        else {
            // record names of open tracks and re-open on new refseq
            var curTracks = this.view.visibleTrackNames();

            this.refSeq = this.allRefs[location.ref];
            this.clearStores();

            this.view.setLocation( this.refSeq,
                                   location.start,
                                   location.end );
            this._updateLocationCookies( location );

            this.showTracks( curTracks );
        }
    }));
},
/**
 * Given a string name, search for matching feature names and set the
 * view location to any that match.
 */
searchNames : function( /**String*/ loc ) {
    var thisB = this;
    this.nameStore.query({ name: loc })
        .then(
            function( nameMatches ) {
                // if we have no matches, pop up a dialog saying so, and
                // do nothing more
                if( ! nameMatches.length ) {
                    new InfoDialog(
                        {
                            title: 'Not found',
                            content: 'Not found: <span class="locString">'+loc+'</span>',
                            className: 'notfound-dialog'
                        }).show();
                    return;
                }

                var goingTo;

                //first check for exact case match
                for (var i = 0; i < nameMatches.length; i++) {
                    if( nameMatches[i].name  == loc )
                        goingTo = nameMatches[i];
                }
                //if no exact case match, try a case-insentitive match
                if( !goingTo ) {
                    for( i = 0; i < nameMatches.length; i++ ) {
                        if( nameMatches[i].name.toLowerCase() == loc.toLowerCase() )
                            goingTo = nameMatches[i];
                    }
                }
                //else just pick a match
                if( !goingTo ) goingTo = nameMatches[0];

                // if it has one location, go to it
                if( goingTo.location ) {

                    //go to location, with some flanking region
                    thisB.showRegionWithHighlight( goingTo.location );
                }
                // otherwise, pop up a dialog with a list of the locations to choose from
                else if( goingTo.multipleLocations ) {
                    new LocationChoiceDialog(
                        {
                            browser: thisB,
                            locationChoices: goingTo.multipleLocations,
                            title: 'Choose '+goingTo.name+' location',
                            prompt: '"'+goingTo.name+'" is found in multiple locations.  Please choose a location to view.'
                        })
                        .show();
                }
            },
            function(e) {
                console.error( e );
                new InfoDialog(
                    {
                        title: 'Error',
                        content: 'Error reading from name store.'
                    }).show();
                return;
            }
   );
},
/**
 * load and display the given tracks
 * @example
 * gb=dojo.byId("GenomeBrowser").genomeBrowser
 * gb.showTracks(["DNA","gene","mRNA","noncodingRNA"])
 * @param trackNameList {Array|String} array or comma-separated string
 * of track names, each of which should correspond to the "label"
 * element of the track information
 */
showTracks : function( trackNames ) {
    this.afterMilestone('initView', dojo.hitch( this, function() {
        
		console.log("Browser.showTracks    trackNames: " + trackNames);
		console.log("Browser.showTracks    this.trackConfigsByName: " + this.trackConfigsByName);
		console.dir({this_trackConfigsByName:this.trackConfigsByName});
		
		if( typeof trackNames == 'string' )
            trackNames = trackNames.split(',');

        if( ! trackNames )
            return;

        var trackConfs = dojo.filter(
            dojo.map( trackNames, function(n) {
				console.log("Browser.showTracks    DOING this.trackConfigsByName(" + n + ")");
				
                          return this.trackConfigsByName[n];
                      }, this),
            function(c) {return c;} // filter out confs that are missing
        );

		console.log("Browser.showTracks    trackConfs: " + trackConfs);
		console.dir({trackConfs:trackConfs});		
		
        // publish some events with the tracks to instruct the views to show them.
		console.log("Browser.showTracks    BEFORE this.publish( '/jbrowse/v1/c/tracks/show', trackConfs )");
        this.publish( '/jbrowse/v1/c/tracks/show', trackConfs );
		console.log("Browser.showTracks    AFTER this.publish( '/jbrowse/v1/c/tracks/show', trackConfs )");

		console.log("Browser.visibleChangedTracks    BEFORE this.publish( '/jbrowse/v1/c/tracks/visibleChanged' )");
        this.publish( '/jbrowse/v1/n/tracks/visibleChanged' );
		console.log("Browser.visibleChangedTracks    AFTER this.publish( '/jbrowse/v1/c/tracks/visibleChanged' )");
    }));
},
/**
 * Create a global keyboard shortcut.
 * @param keychar the character of the key that is typed
 * @param [...] additional arguments passed to dojo.hitch for making the handler
 */
setGlobalKeyboardShortcut : function( keychar ) {
    // warn if redefining
    if( this.globalKeyboardShortcuts[ keychar ] )
        console.warn("WARNING: JBrowse global keyboard shortcut '"+keychar+"' redefined");

    // make the wrapped handler func
    var func = dojo.hitch.apply( dojo, Array.prototype.slice.call( arguments, 1 ) );

    // remember it
    this.globalKeyboardShortcuts[ keychar ] = func;
},
/**
 * Key event handler that implements all global keyboard shortcuts.
 */
globalKeyHandler : function( evt ) {
    // if some digit widget is focused, don't process any global keyboard shortcuts
    if( dijitFocus.curNode )
        return;

    var shortcut = this.globalKeyboardShortcuts[ evt.keyChar || String.fromCharCode( evt.charCode || evt.keyCode ) ];
    if( shortcut ) {
        shortcut.call( this );
        evt.stopPropagation();
    }
},
makeShareLink : function () {
    // don't make the link if we were explicitly configured not to
    if( ( 'share_link' in this.config ) && !this.config.share_link )
        return null;

    var browser = this;
    var shareURL = '#';

    // make the share link
    var button = new dijitButton({
            className: 'share',
            innerHTML: '<span class="icon"></span> Share',
            title: 'share this view',
            onClick: function() {
                URLinput.value = shareURL;
                previewLink.href = shareURL;

                sharePane.show();

                var lp = dojo.position( button.domNode );
                dojo.style( sharePane.domNode, {
                               top: (lp.y+lp.h) + 'px',
                               right: 0,
                               left: ''
                            });
                URLinput.focus();
                URLinput.select();
                copyReminder.style.display = 'block';

                return false;
            }
        }
    );

    // make the 'share' popup
    var container = dojo.create(
        'div', {
            innerHTML: 'Paste this link in <b>email</b> or <b>IM</b>'
        });
    var copyReminder = dojo.create('div', {
                                       className: 'copyReminder',
                                       innerHTML: 'Press CTRL-C to copy'
                                   });
    var URLinput = dojo.create(
        'input', {
            type: 'text',
            value: shareURL,
            size: 50,
            readonly: 'readonly',
            onclick: function() { this.select();  copyReminder.style.display = 'block'; },
            onblur: function() { copyReminder.style.display = 'none'; }
        });
    var previewLink = dojo.create('a', {
        innerHTML: 'Preview',
        target: '_blank',
        href: shareURL,
        style: { display: 'block', "float": 'right' }
    }, container );
    var sharePane = new dijitDialog(
        {
            className: 'sharePane',
            title: 'Share this view',
            draggable: false,
            content: [
                container,
                URLinput,
                copyReminder
            ],
            autofocus: false
        });

    // connect moving and track-changing events to update it
    var updateShareURL = function() {
        shareURL = browser.makeCurrentViewURL();
    };
    dojo.connect( this, "onCoarseMove",                     updateShareURL );
    this.subscribe( '/jbrowse/v1/n/tracks/visibleChanged',  updateShareURL );
    this.subscribe( '/jbrowse/v1/n/globalHighlightChanged', updateShareURL );

    return button.domNode;
},
/**
 * Return a string URL that encodes the complete viewing state of the
 * browser.  Currently just data dir, visible tracks, and visible
 * region.
 * @param {Object} overrides optional key-value object containing
 *                           components of the query string to override
 */
makeCurrentViewURL : function( overrides ) {
    var t = typeof this.config.shareURL;

    if( t == 'function' ) {
        return this.config.shareURL.call( this, this );
    }
    else if( t == 'string' ) {
        return this.config.shareURL;
    }

    return "".concat(
        window.location.protocol,
        "//",
        window.location.host,
        window.location.pathname,
        "?",
        dojo.objectToQuery(
            dojo.mixin(
                dojo.mixin( {}, (this.config.queryParams||{}) ),
                dojo.mixin(
                    {
                        loc:    this.view.visibleRegionLocString(),
                        tracks: this.view.visibleTrackNames().join(','),
                        highlight: (this.getHighlight()||'').toString()
                    },
                    overrides || {}
                )
            )
        )
    );
},
makeFullViewLink : function () {
    var thisB = this;
    // make the link
    var link = dojo.create('a', {
        className: 'topLink',
        href: window.location.href,
        target: '_blank',
        title: 'View in full browser',
        innerHTML: 'Full view'
    });

    var makeURL = this.config.makeFullViewURL || this.makeCurrentViewURL;

    // update it when the view is moved or tracks are changed
    var update_link = function() {
        link.href = makeURL.call( thisB, thisB );
    };
    dojo.connect( this, "onCoarseMove",                     update_link );
    this.subscribe( '/jbrowse/v1/n/tracks/visibleChanged',  update_link );
    this.subscribe( '/jbrowse/v1/n/globalHighlightChanged', update_link );

    return link;
},
/**
 * @private
 */
onCoarseMove : function(startbp, endbp) {

    var currRegion = { start: startbp, end: endbp, ref: this.refSeq.name };

    // update the location box with our current location
    if( this.locationBox ) {
        this.locationBox.set(
            'value',
            Util.assembleLocStringWithLength( currRegion ),
            false //< don't fire any onchange handlers
        );
        this.goButton.set( 'disabled', true ) ;
    }

    // also update the refseq selection dropdown if present
    this._updateRefSeqSelectBox();

    if( this.reachedMilestone('completely initialized') ) {
        this._updateLocationCookies( currRegion );
    }

    // send out a message notifying of the move
    this.publish( '/jbrowse/v1/n/navigate', currRegion );
},
_updateRefSeqSelectBox : function() {
    if( this.refSeqSelectBox ) {

        // if none of the options in the select box match this
        // reference sequence, add another one to the end for it
        if( ! array.some( this.refSeqSelectBox.getOptions(), function( option ) {
                              return option.value == this.refSeq.name;
                        }, this)
          ) {
              this.refSeqSelectBox.set( 'options',
                                     this.refSeqSelectBox.getOptions()
                                     .concat({ label: this.refSeq.name, value: this.refSeq.name })
                                   );
        }

        // set its value to the current ref seq
        this.refSeqSelectBox.set( 'value', this.refSeq.name, false );
    }
},
/**
 * update the location and refseq cookies
 */
_updateLocationCookies : function( location ) {
    var locString = typeof location == 'string' ? location : Util.assembleLocString( location );
    var oldLocMap = dojo.fromJson( this.cookie('location') ) || { "_version": 1 };
    if( ! oldLocMap["_version"] )
        oldLocMap = this._migrateLocMap( oldLocMap );
    oldLocMap[this.refSeq.name] = { l: locString, t: Math.round( (new Date()).getTime() / 1000 ) - 1340211510 };
    oldLocMap = this._limitLocMap( oldLocMap, this.config.maxSavedLocations || 10 );
    this.cookie( 'location', dojo.toJson(oldLocMap), {expires: 60});
},
/**
 * Migrate an old location map cookie to the new format that includes timestamps.
 * @private
 */
_migrateLocMap : function( locMap ) {
    var newLoc = { "_version": 1 };
    for( var loc in locMap ) {
        newLoc[loc] = { l: locMap[loc], t: 0 };
    }
    return newLoc;
},
/**
 * Limit the size of the saved location map, removing the least recently used.
 * @private
 */
_limitLocMap : function( locMap, maxEntries ) {
    // don't do anything if the loc map has fewer than the max


    // CHANGED
    //var locRefs = dojof.keys( locMap );
    var locRefs = Util.dojof.keys( locMap );


    if( locRefs.length <= maxEntries )
        return locMap;

    // otherwise, calculate the least recently used that we need to
    // get rid of to be under the size limit
    locMap = dojo.clone( locMap );
    var deleteLocs =
        locRefs
        .sort( function(a,b){
                   return locMap[b].t - locMap[a].t;
               })
        .slice( maxEntries-1 );

    // and delete them from the locmap
    dojo.forEach( deleteLocs, function(locRef) {
        delete locMap[locRef];
    });

    return locMap;
},
/**
 * Wrapper for dojo.cookie that namespaces our cookie names by
 * prefixing them with this.config.containerID.
 *
 * Has one additional bit of smarts: if an object or array is passed
 * instead of a string to set as the cookie contents, will serialize
 * it with dojo.toJson before storing.
 *
 * @param [...] same as dojo.cookie
 * @returns the new value of the cookie, same as dojo.cookie
 */
cookie : function() {
    arguments[0] = this.config.containerID + '-' + arguments[0];
    if( typeof arguments[1] == 'object' )
        arguments[1] = dojo.toJson( arguments[1] );

    var sizeLimit= this.config.cookieSizeLimit || 1200;
    if( arguments[1] && arguments[1].length > sizeLimit ) {
        console.warn("not setting cookie '"+arguments[0]+"', value too big ("+arguments[1].length+" > "+sizeLimit+")");
        return dojo.cookie( arguments[0] );
    }

    return dojo.cookie.apply( dojo.cookie, arguments );
},
/**
 * @private
 */
createNavBox : function( parent ) {

    // CHANGED
    // ALREADY CREATED navbox IN TEMPLATE
    //var navbox = dojo.create( 'div', { id: 'navbox', style: { 'text-align': 'center' } }, parent );
    var navbox = this.navbox;
    
    // container adds a white backdrop to the locationTrap.
    var locationTrapContainer = dojo.create('div', {className: 'locationTrapContainer'}, navbox );

    this.locationTrap = dojo.create('div', {className: 'locationTrap'}, locationTrapContainer );

    var four_nbsp = String.fromCharCode(160); four_nbsp = four_nbsp + four_nbsp + four_nbsp + four_nbsp;
    navbox.appendChild(document.createTextNode( four_nbsp ));

	// CHANGED
	// 'Save Location' BUTTON WITH CONNECT TO parentWidget.updateViewLocation
	this.saveButton = document.createElement("button");
	this.saveButton.appendChild(document.createTextNode("Save Location"));
	dojo.addClass(this.saveButton, "saveButton");
	var thisObject = this;
	dojo.connect(this.saveButton, "click", function(event) {
		console.log("Browser.createNavBox    Save Location Button click    thisObject.locationBox.value: " + thisObject.locationBox.value);
		console.log("Browser.createNavBox    Save Location Button click    thisObject.refSeqSelectBox.value: " + thisObject.refSeqSelectBox.value);
		
		thisObject.parentWidget.updateViewLocation(thisObject.viewObject, thisObject.locationBox.value, thisObject.refSeqSelectBox.value);
		dojo.stopEvent(event);
	});
	navbox.appendChild(this.saveButton);

    var moveLeft = document.createElement("input");
    moveLeft.type = "image";
    moveLeft.src = this.resolveUrl( "img/slide-left.png" );

	// CHANGED
    //moveLeft.id = "moveLeft";
    moveLeft.id = this.centerPane.containerNode.id + "_moveLeft";
	console.log("Browser.createNavBox    moveLeft.id: " + moveLeft.id);

    moveLeft.className = "icon nav";
    moveLeft.style.height = "40px";
    navbox.appendChild(moveLeft);
    dojo.connect( moveLeft, "click", this,
                  function(event) {
                      dojo.stopEvent(event);
                      this.view.slide(0.9);
                  });

    var moveRight = document.createElement("input");
    moveRight.type = "image";
    moveRight.src = this.resolveUrl( "img/slide-right.png" );
    moveRight.id="moveRight";
    moveRight.className = "icon nav";
    moveRight.style.height = "40px";
    navbox.appendChild(moveRight);
    dojo.connect( moveRight, "click", this,
                  function(event) {
                      dojo.stopEvent(event);
                      this.view.slide(-0.9);
                  });

    navbox.appendChild(document.createTextNode( four_nbsp ));

    var bigZoomOut = document.createElement("input");
    bigZoomOut.type = "image";
    bigZoomOut.src = this.resolveUrl( "img/zoom-out-2.png" );
	
	// CHANGED
    //bigZoomOut.id = "bigZoomOut";
    bigZoomOut.id = this.centerPane.containerNode.id + "_bigZoomOut";
	console.log("Browser.createNavBox    bigZoomOut.id: " + bigZoomOut.id);

    bigZoomOut.className = "icon nav";
    bigZoomOut.style.height = "40px";
    navbox.appendChild(bigZoomOut);
    dojo.connect( bigZoomOut, "click", this,
                  function(event) {
                      dojo.stopEvent(event);
                      this.view.zoomOut(undefined, undefined, 2);
                  });


    var zoomOut = document.createElement("input");
    zoomOut.type = "image";
    zoomOut.src = this.resolveUrl("img/zoom-out-1.png");
	
	// CHANGED
    //zoomOut.id = "zoomOut";
    zoomOut.id = this.centerPane.containerNode.id + "_zoomOut";
	console.log("Browser.createNavBox    zoomOut.id: " + zoomOut.id);

    zoomOut.className = "icon nav";
    zoomOut.style.height = "40px";
    navbox.appendChild(zoomOut);
    dojo.connect( zoomOut, "click", this,
                  function(event) {
                      dojo.stopEvent(event);
                     this.view.zoomOut();
                  });

    var zoomIn = document.createElement("input");
    zoomIn.type = "image";
    zoomIn.src = this.resolveUrl( "img/zoom-in-1.png" );

	// CHANGED
    //zoomIn.id = "zoomIn";
    zoomIn.id = this.centerPane.containerNode.id + "_zoomIn";
	console.log("Browser.createNavBox    zoomIn.id: " + zoomIn.id);

    zoomIn.className = "icon nav";
    zoomIn.style.height = "40px";
    navbox.appendChild(zoomIn);
    dojo.connect( zoomIn, "click", this,
                  function(event) {
                      dojo.stopEvent(event);
                      this.view.zoomIn();
                  });

    var bigZoomIn = document.createElement("input");
    bigZoomIn.type = "image";
    bigZoomIn.src = this.resolveUrl( "img/zoom-in-2.png" );
	
	// CHANGED
    //bigZoomIn.id = "bigZoomIn";
    bigZoomIn.id = this.centerPane.containerNode.id + "_bigZoomIn";
	console.log("Browser.createNavBox    bigZoomIn.id: " + bigZoomIn.id);

    bigZoomIn.className = "icon nav";
    bigZoomIn.style.height = "40px";
    navbox.appendChild(bigZoomIn);
    dojo.connect( bigZoomIn, "click", this,
                  function(event) {
                      dojo.stopEvent(event);
                      this.view.zoomIn(undefined, undefined, 2);
                  });

    navbox.appendChild(document.createTextNode( four_nbsp ));

    // if we have fewer than 30 ref seqs, or `refSeqDropdown: true` is
    // set in the config, then put in a dropdown box for selecting
    // reference sequences
    var refSeqSelectBoxPlaceHolder = dojo.create('span', {}, navbox );

    // make the location box
    this.locationBox = new dijitComboBox(
        {
			// CHANGED
            //id: "location",
			id: this.centerPane.containerNode.id + "_location",

            name: "location",
            style: { width: '25ex' },
            maxLength: 400,
            searchAttr: "name"
        },
        dojo.create('input', {}, navbox) );
    this.afterMilestone( 'loadNames', dojo.hitch(this, function() {
        if( this.nameStore )
            this.locationBox.set( 'store', this.nameStore );
    }));

    this.locationBox.focusNode.spellcheck = false;
    dojo.query('div.dijitArrowButton', this.locationBox.domNode ).orphan();
    dojo.connect( this.locationBox.focusNode, "keydown", this, function(event) {
                      if( event.keyCode == keys.ESCAPE ) {
                          this.locationBox.set('value','');
                      }
                      else if (event.keyCode == keys.ENTER) {
                          this.locationBox.closeDropDown(false);
                          this.navigateTo( this.locationBox.get('value') );
                          this.goButton.set('disabled',true);
                          dojo.stopEvent(event);
                      } else {
                          this.goButton.set('disabled', false);
                      }
                  });
    dojo.connect( navbox, 'onselectstart', function(evt) { evt.stopPropagation(); return true; });
    // monkey-patch the combobox code to make a few modifications
    (function(){

         // add a moreMatches class to our hacked-in "more options" option
         var dropDownProto = eval(this.locationBox.dropDownClass).prototype;
         var oldCreateOption = dropDownProto._createOption;
         dropDownProto._createOption = function( item ) {
             var option = oldCreateOption.apply( this, arguments );
             if( item.hitLimit )
                 dojo.addClass( option, 'moreMatches');
             return option;
         };

         // prevent the "more matches" option from being clicked
         var oldOnClick = dropDownProto.onClick;
         dropDownProto.onClick = function( node ) {
             if( dojo.hasClass(node, 'moreMatches' ) )
                 return null;
             return oldOnClick.apply( this, arguments );
         };
    }).call(this);

    // make the 'Go' button'
    this.goButton = new dijitButton(
        {
            label: 'Go',
            onClick: dojo.hitch( this, function(event) {
                this.navigateTo(this.locationBox.get('value'));
                this.goButton.set('disabled',true);
                dojo.stopEvent(event);
            })
        }, dojo.create('button',{},navbox));


    this.afterMilestone('loadRefSeqs', dojo.hitch( this, function() {

        // make the refseq selection dropdown
        if( this.refSeqOrder && this.refSeqOrder.length ) {
            var max = this.config.refSeqSelectorMaxSize || 30;
            var numrefs = Math.min( max, this.refSeqOrder.length);
            var options = [];
            for ( var i = 0; i < numrefs; i++ ) {
                options.push( { label: this.refSeqOrder[i], value: this.refSeqOrder[i] } );
            }
            var tooManyMessage = '(first '+numrefs+' ref seqs)';
            if( this.refSeqOrder.length > max ) {
                options.push( { label: tooManyMessage , value: tooManyMessage, disabled: true } );
            }

			console.log("Browser.createNavBox    Creating this.refSeqSelectBox");
            this.refSeqSelectBox = new dijitSelectBox({
                name: 'refseq',
                value: this.refSeq ? this.refSeq.name : null,
                options: options,
                onChange: dojo.hitch(this, function( newRefName ) {
                    // don't trigger nav if it's the too-many message
                    if( newRefName == tooManyMessage ) {
                        this.refSeqSelectBox.set('value', this.refSeq.name );
                        return;
                    }

                    // only trigger navigation if actually switching sequences
                    if( newRefName != this.refSeq.name ) {
                        this.navigateToLocation({ ref: newRefName });
                    }
                })
            }).placeAt( refSeqSelectBoxPlaceHolder );

			console.log("Browser.createNavBox    this.refSeqSelectBox:");
			console.dir({this_refSeqSelectBox:this.refSeqSelectBox});
			console.log("Browser.createNavBox    this:");
			console.dir({this:this});
        }

        // calculate how big to make the location box:  make it big enough to hold the
        var locLength = this.config.locationBoxLength || function() {

            // if we have no refseqs, just use 20 chars
            if( ! this.refSeqOrder.length )
                return 20;

            // if there are not tons of refseqs, pick the longest-named
            // one.  otherwise just pick the last one
            var ref = this.refSeqOrder.length < 1000
                && function() {
                       var longestNamedRef;
                       array.forEach( this.refSeqOrder, function(name) {
                                          var ref = this.allRefs[name];
                                          if( ! ref.length )
                                              ref.length = ref.end - ref.start + 1;
                                          if( ! longestNamedRef || longestNamedRef.length < ref.length )
                                              longestNamedRef = ref;
                                      }, this );
                       return longestNamedRef;
                   }.call(this)
                || this.refSeqOrder.length && this.allRefs[ this.refSeqOrder[ this.refSeqOrder.length - 1 ] ]
                || 20;

            var locstring = Util.assembleLocStringWithLength({ ref: ref.name, start: ref.end-1, end: ref.end, length: ref.length });
            //console.log( locstring, locstring.length );
            return locstring.length;
        }.call(this) || 20;


        this.locationBox.domNode.style.width = locLength+'ex';
    }));

	console.log("Browser.createNavBox    this.refSeqSelectBox:");
	console.dir({this_refSeqSelectBox:this.refSeqSelectBox});
	
    return navbox;
},
/**
 * Return the current highlight region, or null if none.
 */
getHighlight : function() {
    return this._highlight || null;
},
/**
 * Set a new highlight.  Returns the new highlight.
 */
setHighlight : function( newHighlight ) {

    if( newHighlight && ( newHighlight instanceof Location ) )
        this._highlight = newHighlight;
    else if( newHighlight )
        this._highlight = new Location( newHighlight );

    this.publish( '/jbrowse/v1/n/globalHighlightChanged', [this._highlight] );

    return this.getHighlight();
},
_updateHighlightClearButton : function() {
    if( this._highlightClearButton ) {
        this._highlightClearButton.set( 'disabled', !!! this._highlight );
        //this._highlightClearButton.set( 'label', 'Clear highlight' + ( this._highlight ? ' - ' + this._highlight : '' ));
    }
},
clearHighlight : function() {
    if( this._highlight ) {
        delete this._highlight;
        this.publish( '/jbrowse/v1/n/globalHighlightChanged', [] );
    }
},
setHighlightAndRedraw : function( location ) {
    var oldHighlight = this.getHighlight();
    if( oldHighlight )
        this.view.hideRegion( oldHighlight );
    this.view.hideRegion( location );
    this.setHighlight( location );
    this.view.showVisibleBlocks( false );
},
/**
 * Clears the old highlight if necessary, sets the given new
 * highlight, and updates the display to show the highlighted location.
 */
showRegionWithHighlight : function( location ) {
    var oldHighlight = this.getHighlight();
    if( oldHighlight )
        this.view.hideRegion( oldHighlight );
    this.view.hideRegion( location );
    this.setHighlight( location );
    this.showRegion( location );
}

}); // END declare

}); // END define

/*

Copyright (c) 2007-2009 The Evolutionary Software Foundation

Created by Mitchell Skinner <mitch_skinner@berkeley.edu>

This package and its accompanying libraries are free software; you can
redistribute it and/or modify it under the terms of the LGPL (either
version 2.1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text.

*/


console.log("plugins.view.jbrowse.src.JBrowse.Browser    COMPLETED");
