use MooseX::Declare;
use Getopt::Simple;

use FindBin qw($Bin);
use lib "$Bin/../..";

class Agua::CLI::Flow with (Logger, Agua::CLI::Timer, Agua::CLI::Util, Agua::Common::Database) {

	#### EXTERNAL
    use File::Path;
    use JSON;
	use Getopt::Simple;
	use TryCatch;
    use Data::Dumper;

	#### INTERNAL
    use Agua::CLI::Project;
    use Agua::CLI::Workflow;
    use Agua::CLI::App;
    use Agua::CLI::Parameter;
	use Agua::Package;
    use Agua::DBaseFactory;

    #### LOGGER
    has 'logtype'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"cli"	);
    has 'logfile'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
    has 'log'		=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);  
    has 'printlog'	=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);
    has 'maxjobs'	=> ( isa => 'Int', is => 'rw', default 	=> 	10 	);
    has 'stagenumber'=> ( isa => 'Int', is => 'rw', default 	=> 	10 	);

    #### STORED LOGISTICS VARIABLES
    has 'owner'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
    has 'username'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
    has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
    has 'project'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'workflow'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'number'	=> ( isa => 'Int|Undef', is => 'rw', default    =>  1	);
    has 'type'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, documentation => q{User-defined workflow type} );
    has 'description'=> ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'notes'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'ordinal'	=> ( isa => 'Str|Undef', is => 'rw', default => undef, required => 0, documentation => q{Set order of appearance: 1, 2, ..., N} );
    has 'workflows'	 => ( isa => 'ArrayRef[Agua::CLI::Workflow]', is => 'rw', default => sub { [] } );
    has 'provenance' => ( isa => 'Str|Undef', is => 'rw', required	=>	0, default => undef);
    has 'scheduler'	 => ( isa => 'Str|Undef', is => 'rw', required	=>	0);
    has 'samplestring' => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    
    #### STORED STATUS VARIABLES
    has 'status'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'locked'	    => ( isa => 'Int|Undef', is => 'rw', default => undef );
    has 'queued'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'started'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'stopped'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'duration'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
    has 'epochqueued'	=> ( isa => 'Maybe', is => 'rw', default => undef );
    has 'epochstarted'	=> ( isa => 'Int|Undef', is => 'rw', default => undef );
    has 'epochstopped'  => ( isa => 'Int|Undef', is => 'rw', default => undef );
    has 'epochduration'	=> ( isa => 'Int|Undef', is => 'rw', default => undef );
    
    #### CONSTANTS
    has 'indent'    => ( isa => 'Int', is => 'ro', default => 15);
    
    #### TRANSIENT VARIABLES
    has 'format'    => ( isa => 'Str', is => 'rw', default => "yaml");
    has 'from'		=> ( isa => 'Str', is => 'rw', required => 0 );
    has 'to'		=> ( isa => 'Str', is => 'rw', required => 0 );
    has 'newname'	=> ( isa => 'Str', is => 'rw', required => 0 );
    has 'appFile'	=> ( isa => 'Str', is => 'rw', required => 0 );
    has 'field'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'value'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'fields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['username', 'database', 'project', 'number', 'workflow', 'owner', 'description', 'notes', 'outputdir', 'field', 'value', 'projfile', 'wkfile', 'outputfile', 'cmdfile', 'start', 'stop', 'ordinal', 'from', 'to', 'status', 'started', 'stopped', 'duration', 'epochqueued', 'epochstarted', 'epochstopped', 'epochduration', 'log', 'printlog', 'scheduler', 'samplestring', 'maxjobs', 'stagenumber', 'format' ] } );
    has 'savefields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['name', 'number', 'owner', 'description', 'notes', 'status', 'started', 'stopped', 'duration', 'locked'] } );
    has 'exportfields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['name', 'number', 'owner', 'description', 'notes', 'status', 'started', 'stopped', 'duration', 'provenance'] } );
    has 'inputfile' => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'projfile'  => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'wkfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'cmdfile'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'projectfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'logfile'   => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'outputfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'outputdir'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
    has 'dbfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'dbtype'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'database'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'user'      => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'password'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
    has 'force'     => ( isa => 'Maybe', is => 'rw', required => 0 );
    has 'start'		=> ( isa => 'Str', is => 'rw', required => 0 );
    has 'stop'		=> ( isa => 'Str', is => 'rw', required => 0 );

    #### OBJECTS
    has 'db'		=> ( isa => 'Agua::DBase::MySQL|Undef', is => 'rw', required => 0 );
    has 'logfh'     => ( isa => 'FileHandle', is => 'rw', required => 0 );
    has 'conf' 		=> (
		is =>	'rw',
		isa => 'Conf::Yaml'
	);

    
####//}}    
    
method BUILD ($args) { 
	$self->logDebug("Project::BUILD()");    
	$self->initialise();
}

method initialise {
	$self->logCaller("");

	$self->owner($self->username()) if not defined $self->owner();
	$self->inputfile($self->projfile()) if defined $self->projfile() and $self->projfile() ne "";
	
	$self->logDebug("Doing self->setDbh");
	$self->setDbh();

	$self->logDebug("inputfile must end in '.proj'") and exit
		if $self->inputfile()
		and not $self->inputfile() =~ /\.proj$/;

	$self->logDebug("outputfile must end in '.proj'") and exit
		if $self->outputfile()
		and not $self->outputfile() =~ /\.proj$/;
}

method getopts {
	$self->_getopts();
	$self->initialise();
}

method _getopts {
	#$self->logDebug("Agua::CLI::Flow::_getopts    \@ARGV: @ARGV");
	my @temp = @ARGV;
	my $args = $self->args();
	
	my $olderr;
	open $olderr, ">&STDERR";	
	open(STDERR, ">/dev/null") or die "Can't redirect STDERR to /dev/null\n";
	my $options = Getopt::Simple->new();
	$options->getOptions($args, "Usage: blah blah");
	open STDERR, ">&", $olderr;

	#$self->logDebug("options->{switch}:");
	#print Dumper $options->{switch};
	my $switch = $options->{switch};
	#print "CLI::Project::switch    ";
	foreach my $key ( keys %$switch ) {
		#print "$key \n" if not defined $switch->{$key};
		#print "CLI::Project::switch    $key : $switch->{$key}\n" if defined $switch->{$key};
		$self->$key($switch->{$key}) if defined $switch->{$key};
	}
	#print "\n";

	@ARGV = @temp;
}

method args {
	my $meta = $self->meta();

	my %option_type_map = (
		'Bool'     => '!',
		'Str'      => '=s',
		'Int'      => '=i',
		'Num'      => '=f',
		'ArrayRef' => '=s@',
		'HashRef'  => '=s%',
		'Maybe'    => ''
	);
	
	my $attributes = $self->fields();
	my $args = {};
	foreach my $attribute_name ( @$attributes )
	{
		my $attr = $meta->get_attribute($attribute_name);
		my $attribute_type  = $attr->{isa};
		#$self->logDebug("attribute_type", $attribute_type);
		
		$attribute_type =~ s/\|.+$//;
		$args -> {$attribute_name} = {  type => $option_type_map{$attribute_type}  };
	}
	#$self->logDebug("args", $args);
	
	return $args;
}

method lock {
	$self->_loadFile() if $self->inputfile();
	$self->locked(1);
	
	$self->logDebug("Locked workflow '"), $self->name(), "'\n";
#        $self->logDebug("self->locked: "), $self->locked(), "\n";
}

method unlock {
	$self->_loadFile() if $self->inputfile();
	$self->locked(0);
	$self->logDebug("Unlocked workflow '"), $self->name(), "'\n";
	#$self->logDebug("self->locked: "), $self->locked(), "\n";
}

#### PROJECT
method addProject {
	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

	#### PROJECT NAME
	my $project		=	$self->project();
	$self->logDebug("project", $project);
	print "Project not defined (use --project option)\n" and exit if not defined $project;

	#### DESCRIPTION
	my $description	=	$self->description();
	$self->logDebug("description", $description);

	#### USERNAME
	my $username    =   $self->setUsername();
	$self->logDebug("username", $username);

	#### LOAD INTO DATABASE
	my $projectobject		=	Agua::CLI::Project->new({
		conf		=>	$self->conf(),
		username	=>	$username,
		name		=>	$project,
		description	=>	$description
	});

	$self->_addProject($projectobject);
}
method _addProject ($projectobject) {
	#### LOAD INTO DATABASE
	my $loader      =   $self->getLoader();        
	$loader->logDebug("loader->db->database", $loader->db()->database());
	my $username	=	$projectobject->username();
	$loader->projectToDatabase($username, $projectobject);

	#### REPORT
	my $project		=	$projectobject->name();
	my $database    =   $self->db()->database();
	print "Project '$project' saved to database '$database'\n";
}

method loadProject {
	$self->logDebug("");

	$self->_getopts();

	#### GET INPUTFILE        
	my $inputfile	=	$self->inputfile();
	$self->logDebug("inputfile", $inputfile);
	print "Can't find inputfile: $inputfile\n" if not -f $inputfile;

	#### SET USERNAME
	my $username    =   $self->setUsername();
	$self->logDebug("username", $username);
	
	#### LOAD INTO DATABASE
	my $projectobject		=	Agua::CLI::Project->new({
		conf		=>	$self->conf(),
		username	=>	$username,
		inputfile	=>	$inputfile,
		log			=>	$self->log(),
		printlog	=>	$self->printlog()
	});
	$projectobject->read();
	
	$self->_addProject($projectobject);
}

method deleteProject {

	#### REMOVE PROJECT FROM ALL DATABASE TABLES
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $project     =   $self->project();
	print "Project not defined (use --project option)\n" and exit if not defined $project;
	
	#### TABLE: project
	my $table       =   "project";
	my $query       =   qq{DELETE FROM project
WHERE username='$username'
AND name='$project'
};
	$self->logDebug("query", $query);
	$self->db()->do($query);

	#### TABLE: workflow
	$table       =   "workflow";
	$query       =   qq{DELETE FROM $table
WHERE username='$username'
AND project='$project'
};
	$self->logDebug("query", $query);
	$self->db()->do($query);

	#### TABLE: stage
	$table          =   "stage";
	$query       =   qq{DELETE FROM $table
WHERE username='$username'
AND project='$project'
};
	$self->logDebug("query", $query);
	$self->db()->do($query);

	#### TABLE: stageparameter
	$table          =   "stageparameter";
	$query       =   qq{DELETE FROM $table
WHERE username='$username'
AND project='$project'
};
	$self->logDebug("query", $query);
	$self->db()->do($query);

	my $database    =   $self->db()->database();
	print "Project '$project' deleted from database '$database'\n";
}

method runProject {
	$self->log(4);
	$self->logDebug("");
	
	#### READ INPUTFILE
	$self->read();

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $project     =   $self->name();

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "project not defined\n" and exit if not defined $project;

	my $workflowhashes		=	$self->getWorkflows($username, $project);
	$self->logDebug("workflowhashes", $workflowhashes);

	my $samplehash			=	$self->getSampleHash($username, $project);
	$self->logDebug("samplehash", $samplehash);

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData($username, $project);
	print "*** NUMBER SAMPLES ***", scalar(@$sampledata), "\n" if defined $sampledata;
	print "**** ZERO SAMPLES ****\n" if not defined $sampledata;

	if ( defined $samplehash ) {
		$self->logDebug("samplehash defined. Doing _runWorkflow");
		foreach my $workflowhash ( @$workflowhashes ) {
			$self->_runWorkflow($workflowhash, $samplehash);
		}
	}
	elsif ( defined $sampledata ) {
		$self->logDebug("sampledata defined. Doing _runWorkflow");
		my $maxjobs  =	2;
		if ( not defined $maxjobs ) {
			$self->logDebug("maxjobs not defined. Doing _runWorkflow loop");
		
			foreach my $samplehash ( @$sampledata ) {
				$self->logDebug("Running workflow with samplehash", $samplehash);
				print "Doing _runWorkflow using sample: ", $samplehash->{sample}, "\n";
					foreach my $workflowhash ( @$workflowhashes ) {
						print "Doing workflow: ", $workflowhash->{workflow}, "\n";
						$self->_runWorkflow($workflowhash, $samplehash);
						my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
						$self->logDebug("success", $success);
						
						return if $success == 0;
				}
			}
		}
		else {
			$self->logDebug("maxjobs defined. Doing _runSampleWorkflow");

			foreach my $workflowhash ( @$workflowhashes ) {
				$self->logDebug("DOING _runSampleWorkflow");
				my $success	=	$self->_runSampleWorkflow($workflowhash, $sampledata);
				$self->logDebug("success", $success);
			}
		}
	}
	else {
		print "Running workflows for project: $project\n";
		foreach my $workflowhash ( @$workflowhashes ) {
			$self->_runWorkflow($workflowhash, undef);
		}
		#print "Completed workflow $workflow\n";
	}
}

method getSampleHash ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	
	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	if ( defined $samplestring ) {
		return	$self->sampleStringToHash($samplestring);
	}

	return undef;
}

method sampleStringToHash ($samplehash) {
	my @entries	=	split "\\|", $samplehash;
	#$self->logDebug("entries", \@entries);
	
	my $hash	=	{};
	foreach my $entry ( @entries ) {
		my ($key, $value)	=	$entry	=~ /^([^:]+):(.+)$/;
		$hash->{$key}	=	$value;
	}
	
	return $hash;
}

method getSampleData ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $query		=	qq{SELECT sampletable FROM sampletable
WHERE username='$username'
AND project='$project'};
	$self->logDebug("query", $query);

	my $table	=	$self->db()->query($query);
	$self->logDebug("table", $table);
	return if not defined $table;
	
	$query			=	qq{SELECT * FROM $table
WHERE username='$username'
AND project='$project'};
	$self->logDebug("query", $query);

	my $sampledata	=	$self->db()->queryhasharray($query);
	#$self->logDebug("sampledata", $sampledata);
	
	return $sampledata;
}

method getWorkflows ($username, $project) {
		#### GET ALL SOURCES
		my $query = qq{SELECT *, name AS workflow, number AS workflownumber FROM workflow
WHERE username='$username'
AND project='$project'
ORDER BY number};
	#$self->logDebug("self->db()", $self->db());
	#$self->logDebug($query);
	my $workflows = $self->db()->queryhasharray($query);
	$workflows = [] if not defined $workflows;
	
	return $workflows;
}

#### WORKFLOW
method addWorkflow {
	$self->logDebug("");

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $project     =   $self->project();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $projecthash	=	$self->_getProjectHash($username, $project);
	$self->logDebug("projecthash", $projecthash);
	print "Can't find project: $project (username: $username)\n" and exit if not defined $projecthash;
	
	#### GET INPUTFILE
	my $workflowfile =   $self->wkfile();
	$self->logDebug("workflow");
	
	#### LOAD INTO DATABASE
	$projecthash->{conf}		=	$self->conf();
	$projecthash->{log}			=	$self->log();
	$projecthash->{printlog}	=	$self->printlog();
	my $projectobject			=	Agua::CLI::Project->new($projecthash);

	my $workflow = Agua::CLI::Workflow->new(
		project     =>  $project,
		username    =>  $self->username(),
		inputfile   =>  $workflowfile,
		log     	=>  $self->log(),
		printlog    =>  $self->printlog(),
		conf        =>  $self->conf(),
		db          =>  $self->db()
	);
	$workflow->_getopts();
	$workflow->_loadFile();

	#### VALIDATE
	$self->logCritical("workflow->name not defined") and exit if not defined $workflow->name();

	#### ADD WORKFLOW OBJECT TO PROJECT OBJECT
	$projectobject->_saveWorkflow($workflow);

	#### LOAD INTO DATABASE
	my $loader      =   $self->getLoader();        
	$loader->logDebug("loader->db->database", $loader->db()->database());
	$loader->projectToDatabase($username, $projectobject);
	
	#### SAVE TO DATABASE
	$workflow->save();

	my $database    =   $self->db()->database();
	print "Added workflow '", $workflow->name(), "' to project '$project' in database '$database'\n";
}

method runWorkflow {
	#$self->log(4);
	$self->logDebug("");

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $project     =   $self->project();
	my $workflow	=	$self->workflow();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "project not defined\n" and exit if not defined $project;
	print "workflow not defined\n" and exit if not defined $workflow;
	
	#### GET WORKFLOW
	my $workflowhash=	$self->getWorkflow($username, $project, $workflow);		
	print "Information for workflow not found: $workflow\n" and exit if not defined $workflowhash;

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData($username, $project);
	#$self->logDebug("Number of samples", scalar(@$sampledata));
	print "Number of samples: ", scalar(@$sampledata), "\n" if defined $sampledata;

	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	if ( defined $samplestring ) {
		my $samplehash		=	$self->sampleStringToHash($samplestring);
		my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
		$self->logDebug("success", $success);
	}
	elsif ( defined $sampledata ) {
		my $maxjobs  =	5;
		if ( not defined $maxjobs ) {
		
			foreach my $samplehash ( @$sampledata ) {
				$self->logDebug("Running workflow with samplehash", $samplehash);
				#print "Running workflow $workflow using sample: ", $samplehash->{sample}, "\n";
				$self->_runWorkflow($workflowhash, $samplehash);
				my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
				$self->logDebug("success", $success);
			}
		}
		else {
			$self->logDebug("DOING _runSampleWorkflow");
			my $success	=	$self->_runSampleWorkflow($workflowhash, $sampledata);
			$self->logDebug("success", $success);
		}
	}
	else {
		#print "Running workflow $workflow\n";
		$self->_runWorkflow($workflowhash, undef);
		#print "Completed workflow $workflow\n";
	}
}

method _runWorkflow ($workflowhash, $samplehash) {
	$self->logDebug("workflowhash", $workflowhash);
	$self->logDebug("samplehash", $samplehash);
	
	$workflowhash->{start}		=	1;
	$workflowhash->{workflow}	=	$workflowhash->{name};
	$workflowhash->{workflownumber}	=	$workflowhash->{number};
	$workflowhash->{samplehash}	=	$samplehash;

	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}		=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();

	$workflowhash->{conf}		=	$self->conf();
	$workflowhash->{db}			=	$self->db();
	$workflowhash->{scheduler}	=	$self->scheduler();
	
	require Agua::Workflow;
	my $object	= Agua::Workflow->new($workflowhash);
	#$self->logDebug("object", $object);
	return $object->executeWorkflow();
}

method _runSampleWorkflow ($workflowhash, $sampledata) {
	$self->logDebug("workflowhash", $workflowhash);
	$workflowhash->{start}		=	1;
	$workflowhash->{workflow}	=	$workflowhash->{name};
	$workflowhash->{workflownumber}	=	$workflowhash->{number};

	#### MAX JOBS
	$workflowhash->{maxjobs}	=	$self->maxjobs();
	
	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}		=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();
	$self->logDebug("workflowhash", $workflowhash);
			
	$workflowhash->{conf}		=	$self->conf();
	$workflowhash->{db}			=	$self->db();
	$workflowhash->{scheduler}	=	$self->scheduler();

	require Agua::Workflow;
	my $object	= Agua::Workflow->new($workflowhash);
	
	#### RUN JOBS IN PARALLEL
	$object->runInParallel($workflowhash, $sampledata);
}

method getSampleJobs ($workflowhash, $sampledata) {
	$self->logDebug("workflowhash", $workflowhash);
	
}


method getWorkflow ($username, $project, $workflow) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);

	return   $self->db()->queryhash("SELECT * FROM workflow WHERE project='$project' and name='$workflow'");
}

method _getProjectHash ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $query	=	qq{SELECT * FROM project
WHERE username='$username'
AND name='$project'};
	$self->logDebug("query", $query);

	my $result	=	$self->db()->queryhash($query);
	$self->logDebug("result", $result);
	
	return undef if not defined $result or $result eq "";
	return $result;
}


method _projectExists ($username, $project) {
	#$self->logDebug("username", $username);
	#$self->logDebug("project", $project);

	my $query	=	qq{SELECT 1 FROM project
WHERE username='$username'
AND name='$project'};
	#$self->logDebug("query", $query);

	my $result	=	$self->db()->query($query);

	return 0 if not defined $result or $result eq "";
	return 1;
}

method loadFromDatabase ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $loader  =   $self->getLoader();

	#### GET WORKFLOWS
	my $query	=	qq{SELECT * FROM project
WHERE username='$username'
AND name='$project'};
	my $data    =   $self->db()->queryhash($query);
	my $workflows = $loader->getWorkflowsByProject($data);
	$self->logDebug("no. workflows", scalar(@$workflows));
	#$self->logDebug("workflows", $workflows);
	
	my $workflowobjects 	=	$loader->getWorkflowObjectsForProject($workflows, $username);
	$self->logDebug("no. workflowobjects", scalar(@$workflowobjects));

	foreach my $workflowobject ( @$workflowobjects ) {
		#### SAVE WORKFLOW TO DATABASE
		$self->_saveWorkflow($workflowobject);
	}
}

method getProjectWorkflowObjects ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $loader  =   $self->getLoader();

	#### GET WORKFLOWS
	my $query	=	qq{SELECT * FROM project
WHERE username='$username'
AND name='$project'};
	my $data    =   $self->db()->queryhash($query);
	my $workflows = $loader->getWorkflowsByProject($data);
	$self->logDebug("no. workflows", scalar(@$workflows));
	#$self->logDebug("workflows", $workflows);
	
	my $workflowobjects 	=	$loader->getWorkflowObjectsForProject($workflows, $username);
	$self->logDebug("no. workflowobjects", scalar(@$workflowobjects));

	return $workflowobjects;	
}

method getProjectWorkflowObject ($username, $project, $workflow) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);

	my $loader  =   $self->getLoader();
	my $workflowobject = $loader->getWorkflowObject({
		username	=>	$username,
		project		=>	$project,
		name		=>	$workflow
	});
	$self->logDebug("workflowobject", $workflowobject);

	return $workflowobject;	
}

method printWorkflow {
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $project     =   $self->project();
	my $workflow	=   $self->workflow();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	
	my $query	=	qq{SELECT * FROM workflow
WHERE username='$username'
AND project='$project'
AND name='$workflow'};
	$self->logDebug("query", $query);
	my $workflowhash	=	$self->db()->queryhash($query);
	$workflowhash->{workflow}	=	$workflowhash->{name};
	
	my $loader		=	$self->getLoader();
	my $workflowobject 	=	$loader->getWorkflowObject($workflowhash);

	my $outputdir	=	$self->outputdir() || ".";
	my $workflownumber	=	$workflowobject->number();
	$self->logDebug("workflownumber", $workflownumber);
	my $workflowfile	=	"$outputdir/$workflownumber-$workflow.work";
	$self->logDebug("workflowfile", $workflowfile);
	
	$workflowobject->_write($workflowfile);
}

#### STAGE
method runStage {
	#$self->log(4);
	$self->logDebug("");

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $project     =   $self->project();
	my $workflow	=	$self->workflow();
	my $stagenumber	=	$self->stagenumber();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("stagenumber", $stagenumber);
	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	my $samplehash		=	undef;
	$samplehash			=	$self->sampleStringToHash($samplestring) if defined $samplestring;
	$self->logDebug("samplehash", $samplehash);

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "project not defined\n" and exit if not defined $project;
	print "workflow not defined\n" and exit if not defined $workflow;
	print "stagenumber not defined\n" and exit if not defined $stagenumber;
	
	#### GET WORKFLOW
	my $workflowhash=	$self->getWorkflow($username, $project, $workflow);		
	$self->logDebug("workflowhash", $workflowhash);
	
	print "Information for workflow not found: $workflow\n" and exit if not defined $workflowhash;
	
	my $success	=	$self->_runStage($workflowhash, $samplehash, $stagenumber);
	$self->logDebug("success", $success);
}

method _runStage ($workflowhash, $samplehash, $stagenumber) {

	$workflowhash->{start}		=	$stagenumber;
	$workflowhash->{stop}		=	$stagenumber;
	$workflowhash->{workflow}	=	$workflowhash->{name};
	$workflowhash->{workflownumber}	=	$workflowhash->{number};
	$workflowhash->{samplehash}	=	$samplehash;

	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}		=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();

	$workflowhash->{conf}		=	$self->conf();
	$workflowhash->{db}			=	$self->db();
	$workflowhash->{scheduler}	=	$self->scheduler();
	
	require Agua::Workflow;
	my $object	= Agua::Workflow->new($workflowhash);
	#$self->logDebug("object", $object);
	return $object->executeWorkflow();
}

#### LOAD
method loadScript {
	$self->log(4);
	$self->logDebug("");

	my $cmdfile = $self->cmdfile();
	$self->logDebug("cmdfile", $cmdfile);
	open(FILE, $cmdfile) or die "Can't open cmdfile: $cmdfile\n";
	$/ = undef;
	my $content = <FILE>;
	close(FILE) or die "Can't close cmdfile: $cmdfile\n";
	$/ = "\n";
	$content =~ s/,\\\n/,/gms;
	#$self->logDebug("content", $content);

	my $sections;
	@$sections = split "####\\s+", $content;
	shift @$sections;
	$self->logDebug("sections[0]", $$sections[0]);
	$self->logDebug("no. sections", scalar(@$sections));

	#### SET OUTPUT DIR		
	my $inputfile	=	$self->inputfile();
	my ($outputdir)	=	$inputfile	=~	/^(.+?)\/[^\/]+$/;
	$outputdir		=	"." if not defined $outputdir;

	my $number		=	0;
	for ( my $i = 0; $i < @$sections; $i++ ) {

		my $section =	$$sections[$i];
		
		next if $section =~ /^\s*$/;
		
		$number++;
		$self->logDebug("section $number", $section);

		my ($name)	=	$section	=~	/^(\S+)/;
		$self->logDebug("name", $name);
		
		require Agua::CLI::Workflow;
		my $workflow = Agua::CLI::Workflow->new({
			name	=>	$name,
			number	=>	$number
		});

		$workflow->_loadScript($section);
		$workflow->_write("$outputdir/$number-$name.work");
	
		#$self->logDebug("workflow:");
		#print $workflow->toString(), "\n";
		$self->_addWorkflow($workflow);
	}
	
	#$self->logDebug("outputfile", $self->inputfile());
	$self->_write();
	
	print "Printed project file: ", $self->inputfile(), "\n";

	return 1;
}

method loadCmd {
	#$self->logDebug("Workflow::loadCmd()");
	
	$self->_loadFile();

	my $cmdfile = $self->cmdfile();
	open(FILE, $cmdfile) or die "Can't open cmdfile: $cmdfile\n";
	$/ = undef;
	my $content = <FILE>;
	close(FILE) or die "Can't close cmdfile: $cmdfile\n";
	$/ = "\n";
	$content =~ s/,\\\n/,/gms;

	my @commands = split "\n\n", $content;
	foreach my $command ( @commands )
	{
		next if $command =~ /^\s*$/;
		require Agua::CLI::Workflow;
		my $workflow = Agua::CLI::Workflow->new();
		$workflow->getopts();
		$workflow->_loadCmd($command);
		#$self->logDebug("app:");
		#print $workflow->toString(), "\n";
		$self->_addWorkflow($workflow);
	}
	
	$self->_write();
	
	return 1;
}

#__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

}


