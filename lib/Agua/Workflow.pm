use MooseX::Declare;

=head2

	PACKAGE		Workflow
	
	PURPOSE
	
		THE Workflow OBJECT PERFORMS THE FOLLOWING TASKS:
		
			1. SAVE WORKFLOWS
			
			2. RUN WORKFLOWS
			
			3. PROVIDE WORKFLOW STATUS

	NOTES

		Workflow::executeWorkflow
			|
			|
			|
			|
		Workflow::runStages
				|
				|
				|
				-> 	my $stage = Agua::Stage->new()
					...
					|
					|
					-> $stage->run()
						|
						|
						? DEFINED 'CLUSTER' AND 'SUBMIT'
						|				|
						|				|
						|				YES ->  Agua::Stage::runOnCluster() 
						|
						|
						NO ->  Agua::Stage::runLocally()

=cut

use strict;
use warnings;
use Carp;

class Agua::Workflow with (Logger, Exchange, Agua::Common) {

#### EXTERNAL MODULES
use Data::Dumper;
use FindBin::Real;
use lib FindBin::Real::Bin() . "/lib";
use TryCatch;

##### INTERNAL MODULES	
use Agua::DBaseFactory;
use Conf::Yaml;
use Agua::Stage;
use Agua::StarCluster;  #
use Agua::Instance;     #
use Agua::Monitor::SGE; #
use Virtual;


# Integers
#has 'log'		=>  ( isa => 'Int', is => 'rw', default => 1 );  
#has 'printlog'		=>  ( isa => 'Int', is => 'rw', default => 4 );
has 'workflowpid'	=> 	( isa => 'Int|Undef', is => 'rw', required => 0 );
has 'workflownumber'=>  ( isa => 'Int|Undef', is => 'rw' );
has 'sample'     	=>  ( isa => 'Str|Undef', is => 'rw' );
has 'start'     	=>  ( isa => 'Int|Undef', is => 'rw' );
has 'stop'     		=>  ( isa => 'Int|Undef', is => 'rw' );
has 'submit'  		=>  ( isa => 'Int|Undef', is => 'rw' );
has 'validated'		=> 	( isa => 'Int|Undef', is => 'rw', default => 0 );
has 'qmasterport'	=> 	( isa => 'Int', is  => 'rw' );
has 'execdport'		=> 	( isa => 'Int', is  => 'rw' );
has 'maxjobs'		=> 	( isa => 'Int', is => 'rw'	);

# Strings
#has 'logfile'		=>  ( isa => 'Str', is => 'rw', default => 1 );  
has 'scheduler'	 	=> 	( isa => 'Str|Undef', is => 'rw', default	=>	"local");
has 'random'		=> 	( isa => 'Str|Undef', is => 'rw', required	=> 	0);
has 'configfile'	=> 	( isa => 'Str|Undef', is => 'rw', default => '' );
has 'installdir'	=> 	( isa => 'Str|Undef', is => 'rw', default => '' );
has 'fileroot'		=> 	( isa => 'Str|Undef', is => 'rw', default => '' );
has 'qstat'			=> 	( isa => 'Str|Undef', is => 'rw', default => '' );
has 'queue'			=>  ( isa => 'Str|Undef', is => 'rw', default => 'default' );
has 'cluster'		=>  ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'whoami'  		=>  ( isa => 'Str', is => 'rw', lazy	=>	1, builder => "setWhoami" );
has 'username'  	=>  ( isa => 'Str', is => 'rw' );
has 'password'  	=>  ( isa => 'Str', is => 'rw' );
has 'workflow'  	=>  ( isa => 'Str', is => 'rw' );
has 'project'   	=>  ( isa => 'Str', is => 'rw' );
has 'outputdir'		=>  ( isa => 'Str', is => 'rw' );
has 'keypairfile'	=> 	( is  => 'rw', 'isa' => 'Str|Undef', required	=>	0	);
has 'keyfile'		=> 	( isa => 'Str|Undef', is => 'rw'	);
has 'instancetype'	=> 	( isa => 'Str|Undef', is  => 'rw', required	=>	0	);
has 'sgeroot'		=> 	( isa => 'Str', is  => 'rw', default => "/opt/sge6"	);
has 'sgecell'		=> 	( isa => 'Str', is  => 'rw', required	=>	0	);
has 'upgradesleep'	=> 	( is  => 'rw', 'isa' => 'Int', default	=>	10	);

# Objects
has 'data'			=> 	( isa => 'HashRef|Undef', is => 'rw', default => undef );
has 'samplehash'	=> 	( isa => 'HashRef|Undef', is => 'rw', required	=>	0	);
has 'ssh'			=> 	( isa => 'Agua::Ssh', is => 'rw', required	=>	0	);
has 'opsinfo'		=> 	( isa => 'Agua::OpsInfo', is => 'rw', required	=>	0	);	
has 'jsonparser'	=> 	( isa => 'JSON', is => 'rw', lazy => 1, builder => "setJsonParser" );
has 'json'			=> 	( isa => 'HashRef', is => 'rw', required => 0 );
has 'db'			=> 	( isa => 'Agua::DBase::MySQL', is => 'rw', lazy	=>	1,	builder	=>	"setDbh" );
has 'stages'		=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'stageobjects'	=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'conf'			=> 	( isa => 'Conf::Yaml', is => 'rw', lazy => 1, builder => "setConf" );
has 'starcluster'	=> 	( isa => 'Agua::StarCluster', is => 'rw', lazy => 1, builder => "setStarCluster" );
has 'head'			=> 	( isa => 'Agua::Instance', is => 'rw', lazy => 1, builder => "setHead" );
has 'master'		=> 	( isa => 'Agua::Instance', is => 'rw', lazy => 1, builder => "setMaster" );
has 'monitor'		=> 	( isa => 'Agua::Monitor::SGE', is => 'rw', lazy => 1, builder => "setMonitor" );
has 'worker'		=> 	( isa => 'Maybe', is => 'rw', required => 0 );
has 'virtual'		=> 	( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );

####////}}}

method BUILD ($hash) {
}

method initialise ($data) {
	#### SET LOG
	my $username 	=	$data->{username};
	my $logfile 	= 	$data->{logfile};
	my $mode		=	$data->{mode};
	$self->logDebug("logfile", $logfile);
	$self->logDebug("mode", $mode);
	if ( not defined $logfile or not $logfile ) {
		my $identifier 	= 	"workflow";
		$self->setUserLogfile($username, $identifier, $mode);
		$self->appendLog($logfile);
	}

	#### IF JSON IS DEFINED, ADD VALUES TO SLOTS
	$self->data($data);
	if ( $data ) {
		foreach my $key ( keys %{$data} ) {
			#$data->{$key} = $self->unTaint($data->{$key});
			$self->$key($data->{$key}) if $self->can($key);
		}
	}
	#$self->logDebug("data", $data);	
	
	#### SET DATABASE HANDLE
	$self->logDebug("Doing self->setDbh");
	$self->setDbh({
		dbuser		=>	$username,
		database	=>	$data->{database}
	}) if not defined $self->db();
    
#	#### VALIDATE
#	$self->logDebug("mode", $mode);
#    $self->notifyError($data, "User session not validated for username: $username") and return 0 unless $mode eq "submitLogin" or $self->validate();
#
	#### SET WORKFLOW PROCESS ID
	$self->workflowpid($$);	

	#### SET CLUSTER IF DEFINED
	$self->logError("Agua::Workflow::BUILD    conf->getKey(agua, CLUSTERTYPE) not defined") if not defined $self->conf()->getKey('agua', 'CLUSTERTYPE');    
	$self->logError("Agua::Workflow::BUILD    conf->getKey(cluster, QSUB) not defined") if not defined $self->conf()->getKey('cluster', 'QSUB');
	$self->logError("Agua::Workflow::BUILD    conf->getKey(cluster, QSTAT) not defined") if not defined $self->conf()->getKey('cluster', 'QSTAT');
}

method setUserLogfile ($username, $identifier, $mode) {
	my $installdir = $self->conf()->getKey("agua", "INSTALLDIR");
	$identifier	=~ s/::/-/g;
	
	return "$installdir/log/$username.$identifier.$mode.log";
}

### EXECUTE PROJECT
method executeProject {
	my $database 	=	$self->database();
	my $username 	=	$self->username();
	my $project 	=	$self->project();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	
	my $fields	=	["username", "project"];
	my $data	=	{
		username	=>	$username,
		project		=>	$project
	};
	my $notdefined = $self->db()->notDefined($data, $fields);
	$self->logError("undefined values: @$notdefined") and return 0 if @$notdefined;
	
	#### RETURN IF RUNNING
	$self->logError("Project is already running: $project") and return if $self->projectIsRunning($username, $project);
	
	#### GET WORKFLOWS
	my $workflows	=	$self->getWorkflowsByProject({
		username	=>	$username,
		name		=>	$project
	});
	$self->logDebug("workflows", $workflows);
	
	#### RUN WORKFLOWS
	my $scheduler	=	$self->conf()->getKey("agua:SCHEDULER", undef);
	$self->logDebug("SCHEDULER", $scheduler);

	if ( $scheduler eq "siphon" ) {
		return $self->runSiphon($username, $project, $workflows);
	}
	else {
		return $self->runProjectWorkflows($username, $project, $workflows);
	}
}

method runProjectWorkflows ($username, $project, $workflows) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $success	=	1;
	foreach my $object ( @$workflows ) {
		$self->logDebug("object", $object);
		$self->username($username);
		$self->project($project);
		my $workflow	=	$object->{name};
		$self->logDebug("workflow", $workflow);
		$self->workflow($workflow);
	
		#### RUN 
		try {
			my $cluster	=	$self->getClusterByWorkflow($username, $project, $workflow);
			$self->logDebug("cluster", $cluster);
			
			$success	=	$self->executeWorkflow();		
			#$self->logError("Workflow $project.$workflow run error") and return 0 if not $success;
		}
		catch {
			print "Workflow::runProjectWorkflows   ERROR\n";
			$self->setProjectStatus("error");
			#$self->notifyError($object, "failed to run workflow '$workflow': $@");
			return 0;
		}
	}
	$self->logGroupEnd("Agua::Project::executeProject");
	
	return $success;
}

method runSiphon ($username, $project, $workflows) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $success	=	1;
	foreach my $workflowobject ( @$workflows ) {
		$self->logDebug("workflowobject", $workflowobject);
		$self->username($username);
		$self->project($project);
		my $workflow	=	$workflowobject->{name};
		$workflowobject->{workflow}	=	$workflowobject->{name};
		$self->logDebug("workflow", $workflow);
		$self->workflow($workflow);

		#### SET STATUS
		#### (WILL BE PICKED UP BY MASTER, WHICH WILL LOAD WORKFLOW TASK QUEUES)
		$self->setProjectStatus($username, $project, "running");
	
		#### RUN 
		try {
			my $cluster	=	$self->getClusterByWorkflow($username, $project, $workflow);
			$self->logDebug("cluster", $cluster);
			
			if ( not defined $cluster or $cluster eq "" ) {
				$success	=	$self->executeWorkflow();
				$self->logDebug("success", $success);
				$self->logError("Workflow $project.$workflow run error") and return 0 if not $success;
			}
			else {
				$self->startSiphonWorkflow($username, $project, $workflow, $cluster, $workflowobject);
				no warnings;
				last;
			}
		}
		catch {
			$self->setProjectStatus($username, $project, "error");
			$self->notifyError($workflowobject, "failed to run workflow '$workflow': $@");
			return 0;
		}
	}
	$self->logDebug("success", $success);
	
	use warnings;

	$self->logGroupEnd("Agua::Project::executeProject");
	
	return $success;
}

method startSiphonWorkflow ($username, $project, $workflow, $cluster, $workflowobject) {
	#	1. GET amiid, instancetype FOR cluster = username.project.workflow
	my $clusterobject	=	$self->getCluster($username, $cluster);
	my $amiid			=	$clusterobject->{amiid};
	my $instancetype	=	$clusterobject->{instancetype};
	my $maxnodes		=	$clusterobject->{maxnodes};
	$self->logDebug("maxnodes", $maxnodes);
	$self->logDebug("amiid", $amiid);
	$self->logDebug("instancetype", $instancetype);
	
	#	2. PRINT USERDATA FILE
	my $userdatafile	=	$self->printConfig($workflowobject);
	
	# 	3. PRINT OPENSTACK AUTHENTICATION *-openrc.sh FILE
	my $virtualtype		=	$self->conf()->getKey("agua", "VIRTUALTYPE");
	my $authfile;
	if ( $virtualtype eq "openstack" ) {
		$authfile	=	$self->printAuth($username);
	}
	$self->logDebug("authfile", $authfile);
	
	#	4. SPIN UP cluster.maxnodes OF VMs FOR FIRST WORKFLOW
	my $name	=	$workflow;
	my $success	=	$self->virtual()->launchNodes($authfile, $amiid, $maxnodes, $instancetype, $userdatafile, $name);
	$self->logDebug("success", $success);
	
	#	5. SET WORKFLOW STATUS
	my $status	=	"running";
	$status		=	"error" if $success == 0;
	$self->bigDisplay("$project.$workflow    $status");
	$self->setWorkflowStatus($username, $project, $workflow, $status) ;
	
	return $success;
}

method printAuth ($username) {
	$self->logDebug("username", $username);
	
	#### SET TEMPLATE FILE	
	my $installdir		=	$self->conf()->getKey("agua", "INSTALLDIR");
	my $templatefile	=	"$installdir/bin/install/resources/openstack/openrc.sh";

	#### GET OPENSTACK AUTH INFO
	my $tenant		=	$self->getTenant($username);
	$self->logDebug("tenant", $tenant);

	#### SET TARGET FILE
	my $targetdir	=	"$installdir/conf/.targetdir";
	`mkdir -p $targetdir` if not -d $targetdir;
	my $tenantname		=	$tenant->{os_tenant_name};
	$self->logDebug("tenantname", $tenantname);
	my $targetfile		=	"$targetdir/$tenantname-openrc.sh";
	$self->logDebug("targetfile", $targetfile);

	#### PRINT FILE
	return	$self->virtual()->printAuthFile($tenant, $templatefile, $targetfile);
}

method getAuthFile ($username, $tenant) {
	$self->logDebug("username", $username);
	
	my $installdir		=	$self->conf()->getKey("agua", "INSTALLDIR");
	my $targetdir	=	"$installdir/conf/.targetdir";
	`mkdir -p $targetdir` if not -d $targetdir;
	my $tenantname		=	$tenant->{os_tenant_name};
	$self->logDebug("tenantname", $tenantname);
	my $authfile		=	"$targetdir/$tenantname-openrc.sh";
	$self->logDebug("authfile", $authfile);

	return	$authfile;
}

method printConfig ($workflowobject) {
	#		GET PACKAGE INSTALLDIR
	my $stages			=	$self->getStagesByWorkflow($workflowobject);
	my $object			=	$$stages[0];
	#$self->logDebug("stages[0]", $object);	

	my $basedir			=	$self->conf()->getKey("agua", "INSTALLDIR");
	$object->{basedir}	=	$basedir;
	
	my $version			=	$object->{version};
	my $package			=	$object->{package};
	
	#		GET TEMPLATE
	my $installdir		=	$object->{installdir};
	my $templatefile	=	$self->setTemplateFile($installdir);
	$self->logDebug("templatefile", $templatefile);
	
	#		PRINT TEMPLATE
	my $username		=	$object->{username};
	my $project			=	$object->{project};
	my $workflow		=	$object->{workflow};
	
	my $virtualtype		=	$self->conf()->getKey("agua", "VIRTUALTYPE");
	my $targetfile		= 	undef;
	if ( $virtualtype eq "openstack" ) {
		my $targetdir	=	"$basedir/conf/.openstack";
		`mkdir -p $targetdir` if not -d $targetdir;
		$targetfile		=	"$targetdir/$username.$project.$workflow.sh";
	}
	elsif ( $virtualtype eq "vagrant" ) {
		my $targetdir	=	"$basedir/conf/.vagrant/$username.$project.$workflow";
		`mkdir -p $targetdir` if not -d $targetdir;
		$targetfile		=	"$targetdir/Vagrantfile";
	}
	$self->logDebug("targetfile", $targetfile);
	
	$self->virtual()->createConfigFile($object, $templatefile, $targetfile);
	
	return $targetfile;
}

method setTemplateFile ($installdir) {
	$self->logDebug("installdir", $installdir);
	
	return "$installdir/data/userdata.tmpl";
}
method getTenant ($username) {
	my $query	=	qq{SELECT *
FROM tenant
WHERE username='$username'};
	$self->logDebug("query", $query);

	return $self->db()->queryhash($query);
}


#### EXECUTE WORKFLOW IN SERIES
method executeWorkflow {
=head2

	SUBROUTINE		executeWorkflow
	
	PURPOSE
	
		WORKFLOW SEQUENCE DIAGRAM
        
		Agua::Workflow.pm -> executeWorkflow()
		|
		|
		-> Agua::Workflow.pm -> runStages()
			|
			| has many Agua::Stages
			|
			-> Agua::Stage -> run()
				| 
				|
				-> Agua::Stage -> execute() LOCAL JOB
				|
				OR
				|
				-> Agua::Stage -> clusterSubmit()  CLUSTER JOB
			
=cut

	my $database 	=	$self->database();
	my $username 	=	$self->username();
	my $cluster 	=	$self->cluster();
	my $project 	=	$self->project();
	my $workflow 	=	$self->workflow();
	my $workflownumber=	$self->workflownumber();
	my $samplehash 	=	$self->samplehash();
	my $start 		=	$self->start();
	my $submit 		= 	$self->submit();
	$self->logDebug("submit", $submit);
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("workflownumber", $workflownumber);
	$self->logDebug("cluster", $cluster);

	#### GET CLUSTER
	$cluster		=	$self->getClusterByWorkflow($username, $project, $workflow) if $cluster eq "";
	$self->logDebug("cluster", $cluster);	
	$self->logDebug("submit", $submit);	
	
	my $data = {
		username		=>	$username,
		project			=>	$project,
		workflow		=>	$workflow,
		workflownumber	=> 	$workflownumber,
		start			=>	$start,
		samplehash		=>	$samplehash
	};

	#### QUIT IF INSUFFICIENT INPUTS
	if ( not $username or not $project or not $workflow or not $workflownumber or not $start ) {
		my $error = '';
		$error .= "username, " if not defined $username;
		$error .= "project, " if not defined $project;
		$error .= "workflow, " if not defined $workflow;
		$error .= "workflownumber, " if not defined $workflownumber;
		$error .= "start, " if not defined $start;
		$error =~ s/,\s+$//;
		$self->notifyError($data, $error);
		return;
	}

	##### QUIT IF RUNNING ALREADY
	#$self->logError("workflow $project.$workflow is already running") and return if $self->workflowIsRunning($username, $project, $workflow);
	
	#### QUIT IF submit BUT cluster IS EMPTY
	$self->notifyError($data, "Cannot run workflow $project.$workflow: cluster not defined") and return if $submit and not $cluster;
	
	$self->notifyError($data, "No AWS credentials for username $username") and return if $submit and not defined $self->_getAws($username);
	
	#### SET WORKFLOW 'RUNNING'
	$self->updateWorkflowStatus($username, $cluster, $project, $workflow, "running");

	#### SET STAGES
	$self->logDebug("DOING self->setStages");
	my $scheduler	=	$self->scheduler() || $self->conf()->getKey("agua:SCHEDULER", undef);
	my $stages = $self->setStages($username, $cluster, $data, $project, $workflow, $workflownumber, $samplehash, $scheduler);
	$self->logDebug("no. stages", scalar(@$stages));
	
	#### NOTIFY RUNNING
	print "Running workflow $project.$workflow\n";
	my $status	=	$self->_getStatus($username, $project, $workflow);
	$self->notifyStatus($status, "Running workflow $project.$workflow");

	#### RUN LOCALLY OR ON CLUSTER
	my $success;
	if ( not defined $cluster or not $cluster or $scheduler eq "local" or not defined $scheduler ) {
		$self->logDebug("DOING self->runLocally");
		$success	=	$self->runLocally($stages, $username, $project, $workflow, $workflownumber, $cluster);
	}
	elsif ( $scheduler eq "sge" ) {
			$self->logDebug("DOING self->runSge");
			$success	=	$self->runSge($stages, $username, $project, $workflow, $workflownumber, $cluster);
	}
	elsif ( $scheduler eq "starcluster" ) {
			$self->logDebug("DOING self->runStarCluster");
			$success	=	$self->runStarCluster($stages, $username, $project, $workflow, $workflownumber, $cluster);
	}

	$self->logDebug("success", $success);
	my $status	=	"completed";
	$status		=	"error" if not $success;

	#### SET WORKFLOW STATUS
	$self->setWorkflowStatus($status, $data);

	#### ADD QUEUE SAMPLE
	my $uuid	=	$samplehash->{sample};
	$success	=	$self->addQueueSample($uuid, $status, $data) if defined $uuid;
	$self->logDebug("addQueueSample success", $success);
	
	#### NOTIFY COMPLETED
	print "Completed workflow $project.$workflow\n";
	#$data->{status}	=	"Completed workflow $project.$workflow";
	#$self->notifyStatus($data);

	$self->logGroupEnd("$$ Agua::Workflow::executeWorkflow    COMPLETED");
}

method setWorkflowStatus ($status, $data) {
	$self->logDebug("status", $status);
	$self->logDebug("data", $data);
	
	my $query = qq{UPDATE workflow
SET status = '$status'
WHERE username = '$data->{username}'
AND project = '$data->{project}'
AND name = '$data->{workflow}'
AND number = $data->{workflownumber}};
	#$self->logDebug("$query");

	my $success = $self->db()->do($query);
	if ( not $success ) {
		$self->logError("Can't update workflow $data->{workflow} (project: $data->{project}) with status: $status");
		return 0;
	}
	
	return 1;
}

method addQueueSample ($uuid, $status, $data) {
	$self->logDebug("uuid", $uuid);
	$self->logDebug("status", $status);
	$self->logDebug("data", $data);
	
	#### SET STATUS
	$data->{status}	=	$status;
	
	#### SET SAMPLE
	$data->{sample}	=	$data->{samplehash}->{sample};
	
	#### SET TIME
	my $time		=	$self->getMysqlTime();
	$data->{time}	=	$time;
	$self->logDebug("data", $data);

	$self->logDebug("BEFORE setDbh    self->db(): " . $self->db());
	$self->setDbh() if not defined $self->db();
	$self->logDebug("AFTER setDbh    self->db(): " . $self->db());
	
	my $table		=	"queuesample";
	my $keys		=	["username", "project", "workflow", "sample"];
	
	$self->logDebug("BEFORE addToTable");
	my $success	=	$self->_addToTable($table, $data, $keys);
	$self->logDebug("AFTER addToTable success", $success);
	
	return $success;
}

#### EXECUTE SAMPLE WORKFLOWS IN PARALLEL
method runInParallel ($workflowhash, $sampledata) {
=head2

	SUBROUTINE		executeCluster
	
	PURPOSE
	
		executeCluster A LIST OF JOBS CONCURRENTLY UP TO A MAX NUMBER
		
		OF CONCURRENT JOBS

=cut

	$self->logCaller("");

	my $username 	=	$self->username();
	my $cluster 	=	$self->cluster();
	my $project 	=	$self->project();
	my $workflow 	=	$self->workflow();
	my $workflownumber=	$self->workflownumber();
	my $start 		=	$self->start();
	my $submit 		= 	$self->submit();
	$self->logDebug("submit", $submit);
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("workflownumber", $workflownumber);
	$self->logDebug("cluster", $cluster);
	
	print "Running workflow $project.$workflow\n";

	#### GET CLUSTER
	$cluster		=	$self->getClusterByWorkflow($username, $project, $workflow) if $cluster eq "";
	$self->logDebug("cluster", $cluster);	
	$self->logDebug("submit", $submit);	
	
	#### RUN LOCALLY OR ON CLUSTER
	my $scheduler	=	$self->scheduler() || $self->conf()->getKey("agua:SCHEDULER", undef);
	$self->logDebug("scheduler", $scheduler);

	#### GET ENVIRONMENT VARIABLES
	my $envars = $self->getEnvars($username, $cluster);
	$self->logDebug("envars", $envars);

	#### CREATE QUEUE FOR WORKFLOW
	$self->createQueue($username, $cluster, $project, $workflow, $envars) if $scheduler eq "sge";

	#### GET STAGES
	my $samplehash	=	undef;
	my $stages	=	$self->setStages($username, $cluster, $workflowhash, $project, $workflow, $workflownumber, $samplehash, $scheduler);
	$self->logDebug("no. stages", scalar(@$stages));
	#$self->logDebug("stages", $stages);

	#### GET FILEROOT
	my $fileroot = $self->getFileroot($username);	
	$self->logDebug("fileroot", $fileroot);

	#### GET OUTPUT DIR
	my $outputdir =  "$fileroot/$project/$workflow/";
	
	#### GET MONITOR
	my $monitor	=	$self->updateMonitor() if $scheduler eq "sge";

	#### SET FILE DIRS
	my ($scriptsdir, $stdoutdir, $stderrdir) = $self->setFileDirs($fileroot, $project, $workflow);
	$self->logDebug("scriptsdir", $scriptsdir);
	
	#### WORKFLOW PROCESS ID
	my $workflowpid = $self->workflowpid();

	$self->logDebug("DOING ALL STAGES stage->setStageJob()");
	foreach my $stage ( @$stages )  {
		#$self->logDebug("stage", $stage);
		my $installdir		=	$stage->installdir();
		$self->logDebug("installdir", $installdir);

		my $jobs	=	[];
		foreach my $samplehash ( @$sampledata ) {
			$stage->{samplehash}	=	$samplehash;
			
			push @$jobs, $stage->setStageJob();
		}
		$self->logDebug("no. jobs", scalar(@$jobs));

		#### SET LABEL
		my $stagename	=	$stage->name();
		$self->logDebug("stagename", $stagename);
		my $label	=	"$project.$workflow.$stagename";

		$stage->runJobs($jobs, $label);
	}

	print "Completed workflow $project.$workflow\n";

	$self->logDebug("COMPLETED");
}

#### RUN STAGES 
method runLocally ($stages, $username, $project, $workflow, $workflownumber, $cluster) {
	$self->logDebug("no. stages", scalar(@$stages));

	#### RUN STAGES
	$self->logDebug("BEFORE runStages()\n");
	my $success	=	$self->runStages($stages);
	$self->logDebug("AFTER runStages    success: $success\n");
	
	if ( $success == 0 ) {
		#### SET WORKFLOW STATUS TO 'error'
		$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'error');
	}
	else {
		#### SET WORKFLOW STATUS TO 'completed'
		$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'completed');
	}
	
	return $success;
}

method runSge ($stages, $username, $project, $workflow, $workflownumber, $cluster) {	
#### RUN STAGES ON SUN GRID ENGINE

	my $sgeroot	=	$self->conf()->getKey("cluster", "SGEROOT");
	my $celldir	=	"$sgeroot/$workflow";
	$self->logDebug("celldir", $celldir);
	$self->_newCluster($username, $workflow) if not -d $celldir;

	#### CREATE UNIQUE QUEUE FOR WORKFLOW
	my $envars = $self->getEnvars($username, $cluster);
	$self->logDebug("envars", $envars);
	$self->createQueue($username, $cluster, $project, $workflow, $envars);

	#### SET CLUSTER WORKFLOW STATUS TO 'running'
	$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'running');
	
	#### SET WORKFLOW STATUS TO 'running'
	$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'running');
	
	### RELOAD DBH
	$self->setDbh();
	
	#### RUN STAGES
	$self->logDebug("BEFORE runStages()\n");
	my $success	=	$self->runStages($stages);
	$self->logDebug("AFTER runStages    success: $success\n");
	
	#### RESET DBH JUST IN CASE
	$self->setDbh();
	
	if ( $success == 0 ) {
		#### SET CLUSTER WORKFLOW STATUS TO 'completed'
		$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'error');
		
		#### SET WORKFLOW STATUS TO 'completed'
		$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'error');
	}
	else {
		#### SET CLUSTER WORKFLOW STATUS TO 'completed'
		$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'completed');
	
		#### SET WORKFLOW STATUS TO 'completed'
		$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'completed');
	}
}
#### STARCLUSTER
method runStarCluster ($stages, $username, $project, $workflow, $workflownumber, $cluster) {
#### 1. LOAD STARCLUSTER
#### 2. CREATE CONFIG FILE
#### 3. START CLUSTER IF NOT RUNNING
#### 4. START BALANCER IF NOT RUNNING
#### 5. START SGE IF NOT RUNNING
#### 6. RUN STAGES

	$self->logDebug("XOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXO");
	
	#### LOAD STARCLUSTER
	$self->loadStarCluster($username, $cluster);
	
	#### CREATE CONFIG FILE IF MISSING
	my $configfile = $self->setConfigFile($username, $cluster);
	$self->createConfigFile($username, $cluster) if not -f $configfile;
	
	#### SET CLUSTER WORKFLOW STATUS TO 'pending'
	$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'pending');
	
	#### SET WORKFLOW STATUS TO 'pending'
	$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'pending');
	
	#### START STARCLUSTER IF NOT RUNNING
	return 0 if not $self->ensureStarClusterRunning($username, $cluster);
	
	### DELETE DEFAULT master -- ALREADY TAKEN CARE OF BY sge.py
	$self->deleteDefaultMaster();
	
	#### GET SGE PORTS
	my ($qmasterport, $execdport) 	= 	$self->getSgePorts();
	
	#### SET MASTER INFO FILE ON HEADNODE
	$self->setMasterInfo($username, $cluster, $qmasterport, $execdport);
	
	#### START BALANCER IF NOT RUNNING
	return 0 if not $self->ensureBalancerRunning($username, $cluster);
	
	#### START SGE IF NOT RUNNING
	return 0 if not $self->ensureSgeRunning($username, $cluster, $project, $workflow);
	
	#### CREATE UNIQUE QUEUE FOR WORKFLOW
	my $envars = $self->getEnvars($username, $cluster);
	$self->logDebug("envars", $envars);
	$self->createQueue($username, $cluster, $project, $workflow, $envars);
	
	#### SET CLUSTER WORKFLOW STATUS TO 'running'
	$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'running');
	
	#### SET WORKFLOW STATUS TO 'running'
	$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'running');
	
	### RELOAD DBH
	$self->setDbh();
	
	#### RUN STAGES
	$self->logDebug("BEFORE runStages()\n");
	my $success	=	$self->runStages($stages);
	$self->logDebug("AFTER runStages    success: $success\n");
	
	#### RESET DBH JUST IN CASE
	$self->setDbh();
	
	if ( $success == 0 ) {
		#### SET CLUSTER WORKFLOW STATUS TO 'completed'
		$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'error');
		
		#### SET WORKFLOW STATUS TO 'completed'
		$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'error');
	}
	else {
		#### SET CLUSTER WORKFLOW STATUS TO 'completed'
		$self->updateClusterWorkflow($username, $cluster, $project, $workflow, 'completed');
	
		#### SET WORKFLOW STATUS TO 'completed'
		$self->updateWorkflowStatus($username, $cluster, $project, $workflow, 'completed');
	}	
	
	#### RETURN IF OTHER WORKFLOWS ARE RUNNING
	my $clusterbusy = $self->clusterIsBusy($username, $cluster);
	$self->logDebug("clusterbusy", $clusterbusy);

	if ( not $clusterbusy ) {
		#### SET CLUSTER FOR TERMINATION
		$self->markForTermination($username, $cluster);
	}
	
	$self->logDebug("COMPLETED");
	
	return $success;
}

method ensureStarClusterRunning ($username, $cluster) {
#### START STARCLUSTER IF NOT RUNNING
	$self->logDebug("");
	
	#### CHECK IF STARCLUSTER IS RUNNING
    $self->logDebug("DOING self->starcluster()->isRunning()");
	my $clusterrunning = $self->starcluster()->isRunning();
	$self->logDebug("clusterrunning", $clusterrunning);
	return 1 if $clusterrunning;
	
	#### START STARCLUSTER IF NOT RUNNING
	my $success = $self->startStarCluster($username, $cluster);
	$self->logDebug("Failed to start cluster") if not $success;

	return $success;
}

method ensureBalancerRunning ($username, $cluster) {
#### START BALANCER IF NOT CLUSTER OR BALANCER RUNNING
	$self->logDebug("");
	
	#### CHECK IF BALANCER IS RUNNING
	my $balancerrunning = $self->starcluster()->balancerRunning();
	$self->logDebug("balancerrunning", $balancerrunning);

	return 1 if $balancerrunning;

	#### START BALANCER IF NOT RUNNING
	my $success = $self->startStarBalancer($username, $cluster);
	$self->logDebug("Failed to start cluster") if not $success;
	
	return $success;
}

method ensureSgeRunning ($username, $cluster, $project, $workflow) {
	$self->logDebug("");
	
	#### RESET DBH JUST IN CASE
	$self->setDbh();
	
	#### CHECK SGE IS RUNNING ON MASTER THEN HEADNODE
	$self->logDebug("DOING self->checkSge($username, $cluster)");
	my $isrunning = $self->checkSge($username, $cluster);
	$self->logDebug("isrunning", $isrunning);
	
	#### RESET DBH IF NOT DEFINED
	$self->logDebug("DOING self->setDbh()");
	$self->setDbh();

	if ( $isrunning ) {
		#### UPDATE CLUSTER STATUS TO 'running'
		$self->updateClusterStatus($username, $cluster, 'SGE running');
		
		return 1;
	}
	else {
		#### SET CLUSTER STATUS TO 'error'
		$self->updateClusterStatus($username, $cluster, 'SGE error');

		$self->logDebug("Failed to start SGE");
		
		return 0;
	}
}

method setStarCluster {
	$self->logCaller("");

	my $starcluster = Agua::StarCluster->new({
		username	=>	$self->username(),
		conf		=>	$self->conf(),
        log     => 	$self->log(),
        printlog    =>  $self->printlog()
    });

	$self->starcluster($starcluster);
}
method loadStarCluster ($username, $cluster) {
#### RETURN INSTANCE OF StarCluster
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	$self->logError("username not defined") and return undef if not defined $username;
	$self->logError("cluster not defined") and return undef if not defined $cluster;

	#### GET CLUSTER INFO
	my $clusterobject = $self->getCluster($username, $cluster);
	$self->logDebug("clusterobject", $clusterobject);
	$self->logError("Agua::Workflow::loadStarCluster    clusterobject not defined") if not defined $clusterobject;

	#### SET SGE PORTS
	my $clustervars = $self->getClusterVars($username, $cluster);
	$self->logDebug("clustervars", $clustervars);
	$clusterobject = $self->addHashes($clusterobject, $clustervars) if defined $clustervars;
	
	### SET whoami
	$clusterobject->{whoami} = $self->whoami();
	
	#### ADD CLUSTER STATUS IF EXISTS
	my $clusterstatus = $self->getClusterStatus($username, $cluster);
	$self->logNote("clusterstatus", $clusterstatus);
	$clusterobject = $self->addHashes($clusterobject, $clusterstatus) if defined $clusterstatus;
	
	#### ADD EC2 KEY FILES
	my $keyfiles = $self->getEc2KeyFiles();
	$self->logNote("keyfiles", $keyfiles);
	$clusterobject = $self->addHashes($clusterobject, $keyfiles) if defined $keyfiles;

	#### ADD CONF
	$clusterobject->{conf} = $self->conf();
	
	#### ADD AWS
	my $aws 		= 	$self->_getAws($username);	
	$self->logDebug("aws", $aws);
	$clusterobject = $self->addHashes($clusterobject, $aws) if defined $aws;
	
	#### SET STARCLUSTER BINARY
	my $executable = $self->conf()->getKey("agua", "STARCLUSTER");
	$self->logDebug("executable", $executable);
	$clusterobject->{executable} = $executable;
	
	#### SET LOG
	$clusterobject->{log} = $self->log();
	$clusterobject->{printlog} = $self->printlog();
	
	#### GET ENVARS
	my $envars = $self->getEnvars($username, $cluster);
	$clusterobject->{envars} = $envars;
	
	#### SET JSON (LEGACY FOR ROLE METHODS)
	#$clusterobject->{json} = $self->json();
	
	#### SET CLUSTER STARTUP WAIT TIME (SECONDS)
	$clusterobject->{tailwait} = 1200;
	
	#### INSTANTIATE STARCLUSTER OBJECT
	$self->logNote("DOING self->starcluster->load(clusterobject)", $clusterobject);
	my $starcluster = $self->starcluster()->load($clusterobject);
	$self->logDebug("AFTER self->starcluster(starcluster)");
	
	return $starcluster;	
}

method startStarCluster ($username, $cluster) {	
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	
	#### UPDATE CLUSTER STATUS TO 'starting'
	$self->logDebug("Starting StarCluster: $cluster\n");
	$self->updateClusterStatus($username, $cluster, "starting cluster");

	#### TERMINATE BALANCER
	$self->starcluster()->terminateBalancer();
	
	#### START STARCLUSTER
	my $success = $self->starcluster()->startCluster();
	$self->logDebug("starcluster->starCluster    success", $success);
	
	#### VERIFY CLUSTER IS RUNNING
	my $isrunning = $self->starcluster()->isRunning();
	$self->logDebug("isrunning", $isrunning);
	
	#### RESET DBH IF NOT DEFINED
	$self->logDebug("DOING self->setDbh()");
	$self->setDbh();

	if ( $isrunning ) {
		#### UPDATE CLUSTER STATUS TO 'running'
		$self->updateClusterStatus($username, $cluster, 'cluster running');
	
		return 1;
	}
	else {
		#### SET CLUSTER STATUS TO 'error'
		$self->updateClusterStatus($username, $cluster, 'cluster error');
		
		return 0;
	}
}

method startStarBalancer ($username, $cluster) {	
#### 1. START STARCLUSTER BALANCER
#### 2. UPDATE BALANCER PID IN clusterstatus TABLE
####. 
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);

	#### START BALANCER
	my $pid = $self->starcluster()->startBalancer();
	$self->logDebug("pid", $pid);
	
	#### RESET DBH
	$self->logDebug("DOING self->setDbh()");
	$self->setDbh();

	#### SET PROCESS PID IN clusterstatus TABLE
	$self->updateClusterPid($username, $cluster, $pid) if $pid;
	
	if ( $pid ) {
		#### UPDATE CLUSTER STATUS TO 'running'
		$self->updateClusterStatus($username, $cluster, 'balancer running');
	
		return 1;
	}
	else {
		#### SET CLUSTER STATUS TO 'error'
		$self->updateClusterStatus($username, $cluster, 'balancer error');
		
		return 0;
	}
}

method markForTermination ($username, $cluster) {
	$self->logDebug("");
	
	#### SET MINNODES TO ZERO	
	$self->starcluster()->minnodes(0);
	$self->logDebug("self->starcluster->minnodes", $self->starcluster()->minnodes());
	
	#### STOP BALANCER
	$self->logDebug("DOING self->starcluster->terminateBalancer");
	$self->starcluster()->terminateBalancer();

	#### RESTART BALANCER (DUE TO TERMINATE)
	$self->logDebug("DOING self->starcluster->launchBalancer");
	my $pid = $self->starcluster()->launchBalancer();
	$self->logDebug("pid", $pid);
	
	return if not defined $pid;

	$self->updateClusterPid($username, $cluster, $pid);	
}

method getEc2KeyFiles {
#### SET PRIVATE KEY AND PUBLIC CERT FILE LOCATIONS	
	my $object = {};

	#### USE ADMIN KEY FILES IF USER IS IN ADMINUSER LIST
	my $username	=	$self->username();
	my $adminkey 	=	$self->getAdminKey($username);
	$self->logDebug("adminkey", $adminkey);

	my $adminuser = $self->conf()->getKey("agua", "ADMINUSER");
	if ( $adminkey ) {
		$object->{privatekey} =  $self->getEc2PrivateFile($adminuser);
		$object->{publiccert} =  $self->getEc2PublicFile($adminuser);
	}
	else {
		$object->{privatekey} =  $self->getEc2PrivateFile($username);
		$object->{publiccert} =  $self->getEc2PublicFile($username);
	}	
	$self->logDebug("privatekey", $object->{privatekey});
	$self->logDebug("publiccert", $object->{publiccert});

	return $object;
}

method stopStarCluster {
	my $username	=	$self->username();
	my $cluster		=	$self->cluster();
	
	#### UPDATE CLUSTER STATUS TO 'stopping'
	$self->updateClusterStatus($username, $cluster, 'stopping');
	
	#### LOAD STARCLUSTER IF NOT LOADED
	$self->logDebug("Doing self->loadStarCluster($username, $cluster) if not loaded");
	$self->loadStarCluster($username, $cluster) if not $self->starcluster()->loaded();
	
	#### STOP STARCLUSTER AND BALANCER
	$self->logDebug("Doing starcluster->stopCluster()");
	my $stopped = $self->starcluster()->stopCluster();	
	
	if ( $stopped ) {
		#### UPDATE CLUSTER STATUS TO 'running'
		$self->updateClusterStatus($username, $cluster, 'stopped');
	
		return 1;
	}
	else {
		#### SET CLUSTER STATUS TO 'error'
		$self->updateClusterStatus($username, $cluster, 'stopping error');
		
		return 0;
	}
}

#### STAGES
method runStages ($stages) {
	$self->logDebug("no. stages", scalar(@$stages));

	#### SELF IS SIPHON WORKER
	my $worker	=	0;
	$worker		=	1 if defined $self->worker();
	$self->logDebug("worker", $worker);
	
	for ( my $stage_counter = 0; $stage_counter < @$stages; $stage_counter++ ) {
		my $stage = $$stages[$stage_counter];
		my $stage_number = $stage->number();
		my $stage_name = $stage->name();
		
		my $username	=	$stage->username();
		my $project		=	$stage->project();
		my $workflow	=	$stage->workflow();
		
		my $mysqltime	=	$self->getMysqlTime();
		$stage->queued($mysqltime);
		$stage->started($mysqltime);
		
		#### CLEAR STDOUT/STDERR FILES
		my $stdoutfile	=	$stage->stdoutfile();
		`rm -fr $stdoutfile` if -f $stdoutfile;
		my $stderrfile	=	$stage->stderrfile();
		`rm -fr $stderrfile` if -f $stderrfile;
		
		#### REPORT STARTING STAGE
		$self->bigDisplayBegin("'$project.$workflow' stage $stage_number $stage_name status: RUNNING");
		
		#### SET STATUS TO running
		$stage->setStatus('running');

		#### NOTIFY STATUS
		if ( $worker ) {
			$self->updateJobStatus($stage, "started");
		}
		else {
			my $data = $self->_getStatus($username, $project, $workflow);
			$self->logDebug("DOING notifyStatus(data)");
			$self->notifyStatus($data);
		}
		
		####  RUN STAGE
		$self->logDebug("Running stage $stage_number", $stage_name);	
		my ($exitcode, $error) = $stage->run();
		$self->logDebug("Stage $stage_number-$stage_name exitcode", $exitcode);
		$self->logDebug("Stage $stage_number-$stage_name error", $error);

		#### STOP IF THIS STAGE DIDN'T COMPLETE SUCCESSFULLY
		#### ALL APPLICATIONS MUST RETURN '0' FOR SUCCESS)
		if ( $exitcode == 0 ) {
			$self->logDebug("Stage $stage_number: '$stage_name' completed successfully");
			$stage->setStatus('completed');
			$self->bigDisplayEnd("'$project.$workflow' stage $stage_number $stage_name status: COMPLETED");
			
			#### NOTIFY STATUS
			my $status	=	"completed";
			if ( $worker ) {
				$self->logDebug("DOING self->updateJobStatus: $status");
				$self->updateJobStatus($stage, $status);
			}
			else {
				my $data = $self->_getStatus($username, $project, $workflow);
				$self->notifyStatus($data);
			}
		}
		else {
			$stage->setStatus('error');
			$self->bigDisplayEnd("'$project.$workflow' stage $stage_number $stage_name status: ERROR");
			#### NOTIFY ERROR
			if ( $worker ) {
				$self->updateJobStatus($stage, "error: $exitcode");
			}
			else {
				my $data = $self->_getStatus($username, $project, $workflow);
				$self->notifyError($data, "Workflow '$project.$workflow' stage #$stage_number '$stage_name' failed. code: $exitcode. error: $error");
			}
			
			return 0;
		}
	}   
	
	return 1;
}

method setStages ($username, $cluster, $data, $project, $workflow, $workflownumber, $samplehash, $scheduler) {
	$self->logGroup("Agua::Workflow::setStages");
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("scheduler", $scheduler);
	
	#### GET SLOTS (NUMBER OF CPUS ALLOCATED TO CLUSTER JOB)
	my $slots	=	$self->getSlots($username, $cluster) if $scheduler eq "sge";
	
	#### SET STAGES
	my $stages = $self->getStages($data);
	
	#### VERIFY THAT PREVIOUS STAGE HAS STATUS completed
	return [] if not $self->checkPrevious($stages, $data);

	#### GET STAGE PARAMETERS FOR THESE STAGES
	$stages = $self->setStageParameters($stages, $data);
	
	#### SET START AND STOP
	my ($start, $stop) = $self->setStartStop($stages, $data);
	$self->logDebug("start", $start);
	$self->logDebug("stop", $stop);
	
	#### GET FILEROOT
	my $fileroot = $self->getFileroot($username);	
	$self->logDebug("fileroot", $fileroot);
	
	#### SET FILE DIRS
	my ($scriptsdir, $stdoutdir, $stderrdir) = $self->setFileDirs($fileroot, $project, $workflow);
	$self->logDebug("scriptsdir", $scriptsdir);
	
	#### WORKFLOW PROCESS ID
	my $workflowpid = $self->workflowpid();

	#### CLUSTER, QUEUE AND QUEUE OPTIONS
	my $queue = $self->queueName($username, $project, $workflow);
	#my $queue_options = $self->data()->{queue_options};
	
	#### SET OUTPUT DIR
	my $outputdir =  "$fileroot/$project/$workflow";

	#### GET ENVIRONMENT VARIABLES
	my $envars = $self->getEnvars($username, $cluster);

	#### GET MONITOR
	$self->logDebug("BEFORE monitor = self->updateMonitor()");
	my $monitor	= 	undef;
	#$monitor = $self->updateMonitor() if $scheduler eq "sge" or $scheduler eq "starcluster";
	$monitor = $self->updateMonitor();
	$self->logDebug("AFTER monitor = self->updateMonitor()");

	#### MAX JOBS
	my $maxjobs	=	$self->maxjobs();
	$self->logDebug("maxjobs", $maxjobs);
	
	#### LOAD STAGE OBJECT FOR EACH STAGE TO BE RUN
	my $stageobjects = [];
	for ( my $counter = $start; $counter < $stop; $counter++ ) {
		my $stage = $$stages[$counter];
		$self->logDebug("stage $start (stop $stop)", $stage);
		
		my $stagenumber	=	$stage->{number};
		my $stagename	=	$stage->{name};
		my $id			=	$samplehash->{sample};
		
		#### STOP IF NO STAGE PARAMETERS
		$self->logDebug("stageparameters not defined for stage $counter $stage->{name}") and last if not defined $stage->{stageparameters};
		
		my $stage_number = $counter + 1;

		#### SET SCHEDULER
		$stage->{scheduler}		=	$scheduler;
		
		#### SET MONITOR
		$stage->{monitor} = $monitor;

		#### SET SGE ENVIRONMENT VARIABLES
		$stage->{envars} = $envars;
		
        #### SET SCRIPT, STDOUT AND STDERR FILES
		$stage->{scriptfile} 	=	"$scriptsdir/$stagenumber-$stagename.sh";
		$stage->{stdoutfile} 	=	"$stdoutdir/$stagenumber-$stagename.stdout";
		$stage->{stderrfile} 	= 	"$stderrdir/$stagenumber-$stagename.stderr";

		if ( defined $id ) {
			$stage->{scriptfile} 	=	"$scriptsdir/$stagenumber-$stagename-$id.sh";
			$stage->{stdoutfile} 	=	"$stdoutdir/$stagenumber-$stagename-$id.stdout";
			$stage->{stderrfile} 	= 	"$stderrdir/$stagenumber-$stagename-$id.stderr";
		}

		$stage->{cluster}		=  	$cluster;
		$stage->{workflowpid}	=	$workflowpid;
		$stage->{db}			=	$self->db();
		$stage->{conf}			=  	$self->conf();
		$stage->{fileroot}		=  	$fileroot;

		#### MAX JOBS
		$stage->{maxjobs}		=	$self->maxjobs();

		#### SLOTS
		$stage->{slots}			=	$slots;

		#### QUEUE
		$stage->{queue}			=  	$queue;

		#### SAMPLE HASH
		$stage->{samplehash}	=  	$samplehash;
		#### LATER: REPLACE
		#$stage->{queue_options}	=  	$queue_options;

		$stage->{outputdir}		=  	$outputdir;
		$stage->{qsub}			=  	$self->conf()->getKey("cluster", "QSUB");
		$stage->{qstat}			=  	$self->conf()->getKey("cluster", "QSTAT");
		$stage->{envars}		=  	$self->envars();

		#### ADD LOG INFO
		$stage->{log} 			=	$self->log();
		$stage->{printlog} 		=	$self->printlog();
		$stage->{logfile} 		=	$self->logfile();

		my $stageobject = Agua::Stage->new($stage);

		#### NEAT PRINT STAGE
		#$stageobject->toString();

		push @$stageobjects, $stageobject;
	}

	#### SET self->stages()
	$self->stages($stageobjects);
	$self->logDebug("final no. stageobjects", scalar(@$stageobjects));
	
	$self->logGroupEnd("Agua::Workflow::setStages");

	return $stageobjects;
}

method getSlots ($username, $cluster) {
	$self->logCaller("");

	return if not defined $username;
	return if not defined $cluster;
	
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	
	#### SET INSTANCETYPE
	my $clusterobject = $self->getCluster($username, $cluster);
	$self->logDebug("clusterobject", $clusterobject);
	my $instancetype = $clusterobject->{instancetype};
	$self->logDebug("instancetype", $instancetype);
	$self->instancetype($instancetype);

	$self->logDebug("DOING self->setSlotNumber");
	my $slots = $self->setSlotNumber($instancetype);
	$slots = 1 if not defined $slots;
	$self->logDebug("slots", $slots);

	return $slots;	
}

method setFileDirs ($fileroot, $project, $workflow) {
	$self->logDebug("fileroot", $fileroot);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	my $scriptsdir = $self->createDir("$fileroot/$project/$workflow/scripts");
	my $stdoutdir = $self->createDir("$fileroot/$project/$workflow/stdout");
	my $stderrdir = $self->createDir("$fileroot/$project/$workflow/stdout");
	$self->logDebug("scriptsdir", $scriptsdir);

	#### CREATE DIRS	
	`mkdir -p $scriptsdir` if not -d $scriptsdir;
	`mkdir -p $stdoutdir` if not -d $stdoutdir;
	`mkdir -p $stderrdir` if not -d $stderrdir;
	$self->logError("Cannot create directory scriptsdir: $scriptsdir") and return undef if not -d $scriptsdir;
	$self->logError("Cannot create directory stdoutdir: $stdoutdir") and return undef if not -d $stdoutdir;
	$self->logError("Cannot create directory stderrdir: $stderrdir") and return undef if not -d $stderrdir;		

	return $scriptsdir, $stdoutdir, $stderrdir;
}

method getStageApp ($stage) {
	$self->logDebug("stage", $stage);
	
	my $appname		=	$stage->name();
	my $installdir	=	$stage->installdir();
	my $version		=	$stage->version();
	
	my $query	=	qq{SELECT * FROM package
WHERE appname='$stage->{appname}'
AND installdir='$stage->{installdir}'
AND version='$stage->{version}'
};
	$self->logDebug("query", $query);
	my $app	=	$self->db()->query($query);
	$self->logDebug("app", $app);

	return $app;
}
method getStageFields {
	return [
		'username',
		'project',
		'workflow',
		'workflownumber',
		'samplehash',
		'name',
		'number',
		'location',
		'installdir',
		'version',
		'queued',
		'started',
		'completed'
	];
}

method updateJobStatus ($stage, $status) {
	#$self->logDebug("status", $status);
	
	#### FLUSH
	$| = 1;
	
	$self->logDebug("stage", $stage->name());

	#### POPULATE FIELDS
	my $data	=	{};
	my $fields	=	$self->getStageFields();
	foreach my $field ( @$fields ) {
		$data->{$field}	=	$stage->$field();
	}

	#### SET QUEUE IF NOT DEFINED
	my $queue		=	"update.job.status";
	$self->logDebug("queue", $queue);
	$data->{queue}	=	$queue;
	
	#### SAMPLE HASH
	my $samplehash		=	$self->samplehash();
	#$self->logDebug("samplehash", $samplehash);
	my $sample			=	$self->sample();
	#$self->logDebug("sample", $sample);
	$data->{sample}		=	$sample;
	
	#### TIME
	$data->{time}		=	$self->getMysqlTime();
	#$self->logDebug("after time", $data);
	
	#### MODE
	$data->{mode}		=	"updateJobStatus";
	
	#### ADD stage... TO NAME AND NUMBER
	$data->{stage}		=	$stage->name();
	$data->{stagenumber}=	$stage->number();

	#### ADD ANCILLARY DATA
	$data->{status}		=	$status;	
	$data->{host}		=	$self->getHostName();
	$data->{ipaddress}	=	$self->getIpAddress();
	#$self->logDebug("after host", $data);

	#### ADD STDOUT AND STDERR
	my $stdout 			=	"";
	my $stderr			=	"";
	$stdout				=	$self->getFileContents($stage->stdoutfile()) if -f $stage->stdoutfile();
	$stderr				=	$self->getFileContents($stage->stderrfile()) if -f $stage->stderrfile();
	$data->{stderr}		=	$stderr;
	$data->{stdout}		=	$stdout;
	
	#### SEND TOPIC	
	$self->logDebug("DOING self->worker->sendTask(data)");
	$self->worker()->sendTask($data);
	$self->logDebug("AFTER self->worker->sendTask(data)");
}

method getIpAddress {
	my $ipaddress	=	`facter ipaddress`;
	$ipaddress		=~ 	s/\s+$//;
	$self->logDebug("ipaddress", $ipaddress);
	
	return $ipaddress;
}

method getHostName {
	my $facter		=	`which facter`;
	$facter			=~	s/\s+$//;
	#$self->logDebug("facter", $facter);
	my $hostname	=	`$facter hostname`;	
	$hostname		=~ 	s/\s+$//;
	#$self->logDebug("hostname", $hostname);

	return $hostname;	
}

method getWorkflowStages ($json) {
	my $username = $json->{username};
    my $project = $json->{project};
    my $workflow = $json->{workflow};

	#### CHECK INPUTS
    $self->logError("Agua::Workflow::getWorkflowStages    username not defined") if not defined $username;
    $self->logError("Agua::Workflow::getWorkflowStages    project not defined") if not defined $project;
    $self->logError("Agua::Workflow::getWorkflowStages    workflow not defined") if not defined $workflow;

	#### GET ALL STAGES FOR THIS WORKFLOW
    my $query = qq{SELECT * FROM stage
WHERE username ='$username'
AND project = '$project'
AND workflow = '$workflow'
ORDER BY number};
    $self->logNote("$$ $query");
    my $stages = $self->db()->queryhasharray($query);
	$self->logError("stages not defined for username: $username") and return if not defined $stages;	

	$self->logNote("$$ stages:");
	foreach my $stage ( @$stages )
	{
		my $stage_number = $stage->number();
		my $stage_name = $stage->name();
		my $stage_submit = $stage->submit();
		print "Agua::Workflow::runStages    stage $stage_number: $stage_name [submit: $stage_submit]";
	}

	return $stages;
}

method checkPrevious ($stages, $json) {
	#### IF NOT STARTING AT BEGINNING, CHECK IF PREVIOUS STAGE COMPLETED SUCCESSFULLY
	
	my $start = $json->{start};
    $start--;	
	$self->logDebug("start", $start);
	return 1 if $start <= 0;

	my $stage_number = $start - 1;
	$$stages[$stage_number]->{appname} = $$stages[$stage_number]->{name};
	$$stages[$stage_number]->{appnumber} = $$stages[$stage_number]->{number};
	my $keys = ["username", "project", "workflow", "name", "number"];
	my $where = $self->db()->where($$stages[$stage_number], $keys);
	my $query = qq{SELECT status FROM stage $where};
	my $status = $self->db()->query($query);
	
	return 1 if not defined $status or not $status;
	$self->logError("previous stage not completed: $stage_number") and return 0 if $status ne "completed";
	return 1;
}

method setStageParameters ($stages, $data) {
	#### GET THE PARAMETERS FOR THE STAGES WE WANT TO RUN
	#$self->logDebug("stages", $stages);
	#$self->logDebug("data", $data);
	
	#### GET THE PARAMETERS FOR THE STAGES WE WANT TO RUN
	my $start = $data->{start} || 1;
    $start--;
	for ( my $i = $start; $i < @$stages; $i++ ) {
		$$stages[$i]->{appname} = $$stages[$i]->{name};
		$$stages[$i]->{appnumber} = $$stages[$i]->{number};
		my $keys = ["username", "project", "workflow", "appname", "appnumber"];
		my $where = $self->db()->where($$stages[$i], $keys);
		my $query = qq{SELECT * FROM stageparameter
$where AND paramtype='input'
ORDER BY ordinal};
		#$self->logDebug("query", $query);

		my $stageparameters = $self->db()->queryhasharray($query);
		$self->logNote("stageparameters", $stageparameters);
		$$stages[$i]->{stageparameters} = $stageparameters;
	}
	
	return $stages;
}

method setStartStop ($stages, $json) {
	$self->logNote("$$ No. stages: " . scalar(@$stages));
	$self->logDebug("stages is empty") and return if not scalar(@$stages);

	my $start = $self->start();
	$self->logDebug("json->{start} not defined") and return if not defined $start;
	$self->logDebug("start is non-numeric: $start") and return if $start !~ /^\d+$/;
	$start--;

	$self->logDebug("Runner starting stage $start is greater than the number of stages") and return if $start > @$stages;

	my $stop = $self->stop();
	if ( defined $stop and $stop ne '' ) {
		$self->logDebug("stop is non-numeric: $stop") and return if $stop !~ /^\d+$/;
		$self->logDebug("Runner stoping stage $stop is greater than the number of stages") and return if $stop > scalar(@$stages) + 1;
		$stop--;
	}
	else {
		$stop = scalar(@$stages) - 1;
	}
	
	if ( $start > $stop ) {
		$self->logDebug("start ($start) is greater than stop ($stop)");
	}

	$self->logNote("$$ Setting start: $start");	
	$self->logNote("$$ Setting stop: $stop");	
	
	$self->start($start);
	$self->stop($stop);
	
	return ($start, $stop);
}

#### QUEUE
method deleteDefaultMaster {
	#### DELETE 'master' FROM ADMIN, SUBMIT AND EXECUTION HOST LISTS
	$self->logDebug("");
	my $output = $self->removeFromAllHosts("master");
	$self->logDebug("output", $output);
	
	$self->deleteAdminHost("master");
	$self->deleteSubmitHost("master");
	$self->deleteExecutionHost("master");
}

method setMasterInfo ($username, $cluster, $qmasterport, $execdport) {
#### 1. SET qmaster_info
#### 2. SET HEADNODE common/act_qmaster
#### 3. SET MASTER common/act_qmaster
#### 4. UPDATE MASTER dnsname IN @allhosts GROUP hostlist

	$self->logDebug("username", $username);

	#### LOAD STARCLUSTER IF NOT ALREADY LOADED
	$self->loadStarCluster($username, $cluster) if not $self->starcluster()->loaded();

	#### QUIT IF CLUSTER DOES NOT EXIST
	my $exists = $self->starcluster()->instance()->exists();
	$self->logDebug("exists", $exists);
	return if not $exists;

	#### GET STORED AND CURRENT MASTER EXTERNAL FQDN
	my $newexternalfqdn = $self->starcluster()->instance()->master()->externalfqdn();
	$self->logDebug("newexternalfqdn", $newexternalfqdn);
	my $masterinfo = $self->getHeadnodeMasterInfo($cluster);
	$self->logDebug("masterinfo", $masterinfo);
	my $oldexternalfqdn = $masterinfo->{externalfqdn};
	$self->logDebug("oldexternalfqdn", $oldexternalfqdn);
	
	#### QUIT IF MASTER INSTANCE HAS NOT CHANGED
	return $masterinfo if $newexternalfqdn eq $oldexternalfqdn;
	
	#### GET NEW MASTER INSTANCE INFO
	my $instanceinfo	= $self->getMasterInstanceInfo($username, $cluster);
	$self->logDebug("instanceinfo", $instanceinfo);
	my $newname 		= $instanceinfo->{internalfqdn};
	my $internalip 		= $instanceinfo->{internalip};
	my $instanceid 		= $instanceinfo->{instanceid};
	my $externalfqdn 	= $instanceinfo->{externalfqdn};
	my $externalip 		= $instanceinfo->{externalip};
	$self->logDebug("newname", $newname);
	
	#### 1. SET HEADNODE qmaster_info
	$self->_setHeadnodeMasterInfo($cluster, $newname, $internalip, $instanceid, $externalfqdn, $externalip);
	
	#### 2. UPDATE HEADNODE act_qmaster 
	$self->setHeadnodeActQmaster($cluster, $newname);
	
	#### 3. UPDATE MASTER act_qmaster 
	$self->setMasterActQmaster($cluster, $newname);
	
	#### 4. UPDATE MASTER dnsname IN @allhosts GROUP hostlist
	$self->addToAllHosts($newname);
	
	##### 5. UPDATE MASTER dnsname IN SUBMIT HOSTS LIST
	#$self->setSgeSubmitHosts($cluster, $qmasterport, $execdport, $oldname, $newname) if $oldname ne $newname;
	
	##### RESTART HEADNODE SGE EXECD
	#$self->restartHeadnodeSge($execdport);
	
	return $instanceinfo;
}

method createQueue ($username, $cluster, $project, $workflow, $envars) {
	$self->logCaller("");
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	$self->logDebug("envars", $envars);
	
	$self->logError("Agua::Workflow::createQueue    project not defined") if not defined $project;
	$self->logError("Agua::Workflow::createQueue    workflow not defined") if not defined $workflow;

	my $headip = $self->getHeadnodeInternalIp();
	$self->logDebug("headip", $headip);
	
	#### SET VARIABLES
	$self->username($username);
	$self->cluster($cluster);
	$self->project($project);
	$self->workflow($workflow);
	$self->qmasterport($envars->{qmasterport});
	$self->execdport($envars->{execdport});
	$self->sgecell($envars->{sgecell});
	$self->sgeroot($envars->{sgeroot});

	#### CREATE QUEUE FOLDER IF NOT EXISTS
	my $sgeroot		=	$envars->{sgeroot};
	my $sgecell		=	$envars->{sgecell};
	
	my $queuedirectory	=	"$sgeroot/$sgecell";
	$self->logDebug("queuedirectory", $queuedirectory);
	`cp -r $sgeroot/default $queuedirectory` if not -d $queuedirectory;
	
	#### SET CONFIGFILE
	my $adminkey = $self->getAdminKey($username);
	$self->logDebug("adminkey", $adminkey);
	my $adminuser = $self->conf()->getKey("agua", "ADMINUSER");
	my $configfile;
	$configfile =  $self->setConfigFile($username, $cluster) if not $adminkey;
	$configfile =  $self->setConfigFile($username, $cluster, $adminuser) if $adminkey;
	$self->configfile($configfile);
	
	#### SET INSTANCETYPE
	my $clusterobject = $self->getCluster($username, $cluster);
	$self->logDebug("clusterobject", $clusterobject);
	my $instancetype = $clusterobject->{instancetype};
	$self->logDebug("instancetype", $instancetype);

	$self->instancetype($instancetype);
	
	#### CREATE QUEUE
	my $queue = $self->queueName($username, $project, $workflow);
	my $qmasterport = $envars->{qmasterport};
	my $execdport = $envars->{execdport};
	$self->logDebug("queue", $queue);
	$self->logDebug("qmasterport", $qmasterport);
	$self->logDebug("execdport", $execdport);

	#### SET QUEUE
	$self->logDebug("Doing self->setQueue($queue)\n");
	$self->setQueue($queue, $qmasterport, $execdport, $instancetype);

	$self->logGroupEnd("Agua::Workflow::createQueue    COMPLETED");
}

method deleteQueue ($project, $workflow, $username, $cluster, $envars) {
	$self->logError("Agua::Workflow::deleteQueue    project not defined") if not defined $project;
	$self->logError("Agua::Workflow::deleteQueue    workflow not defined") if not defined $workflow;

	#### GET ENVIRONMENT VARIABLES FOR THIS CLUSTER/CELL
	my $args = $self->json();
	$args->{qmasterport} = $envars->{qmasterport};
	$args->{execdport} = $envars->{execdport};
	$args->{sgecell} = $envars->{sgecell};
	$args->{sgeroot} = $envars->{sgeroot};

	#### DETERMINE WHETHER TO USE ADMIN KEY FILES
	my $adminkey = $self->getAdminKey($username);
	$self->logDebug("adminkey", $adminkey);
	return if not defined $adminkey;
	my $adminuser = $self->conf()->getKey("agua", "ADMINUSER");
	$args->{configfile} =  $self->setConfigFile($username, $cluster) if not $adminkey;
	$args->{configfile} =  $self->setConfigFile($username, $cluster, $adminuser) if $adminkey;
	$self->logDebug("configfile", $args->{configfile});

	#### ADD CONF OBJECT	
	$args->{conf} = $self->conf();

	$self->logDebug("args", $args);
	
	#### RUN starcluster.pl TO GENERATE KEYPAIR FILE IN .starcluster DIR
	my $queue = $self->queueName($username, $project, $workflow);
	$self->logDebug("queue", $queue);

#    #### SET STARCLUSTER
#	my $starcluster = $self->starcluster();
#	$starcluster = $self->starcluster()->load($args) if not $self->starcluster()->loaded();
    
    #### UNSET QUEUE
#    $self->logDebug("Doing StarCluster->unsetQueue($queue)");
#	$starcluster->unsetQueue($queue);
    $self->logDebug("Doing self->unsetQueue($queue)");
	$self->unsetQueue($queue);
}

#### QUEUE
method setQueue ($queue, $qmasterport, $execdport, $instancetype) {
	$self->logCaller("");
	$self->logDebug("instancetype", $instancetype);

	$self->logDebug("DOING self->setPE()");
	$self->setPE("threaded", $queue);

	$self->logDebug("DOING self->setSlotNumber");
	my $slots = $self->setSlotNumber($instancetype);
	$slots = 1 if not defined $slots;
	$self->logDebug("slots", $slots);
	$self->logDebug("self->qmasterport", $self->qmasterport());
	
	my $maxjobs		=	$self->maxjobs();
	$self->logDebug("maxjobs", $maxjobs);

	#### SET QUEUE SLOTS (MAX TOTAL CPUS AVAILABLE IN THE QUEUE)
	my $queueslots	=	$slots * $maxjobs;
	
	my $parameters = {
		qname			=>	$queue,
		slots			=>	$queueslots,
		shell			=>	"/bin/bash",
		hostlist		=>	"\@allhosts",
		load_thresholds	=>	"np_load_avg=20"
	};

	my $queuefile = $self->getQueuefile("queue-$queue");
	$self->logDebug("queuefile", $queuefile);
	
	my $exists = undef;
	
	#my $exists = $self->queueExists($queue, $qmasterport, $execdport);
	$self->logDebug("exists", $exists);
	
	$self->_addQueue($queue, $queuefile, $parameters) if not $exists;
}

method unsetQueue ($queue) {
	my $queuefile = $self->getQueuefile("queue-$queue");
	$self->logDebug("queuefile", $queuefile); 
	
	$self->_removeQueue($queue, $queuefile);
}

method setPE ($pe, $queue) {
 	$self->logDebug("pe", $pe);
 	$self->logDebug("queue", $queue);

	$self->logDebug("DOING self->setSlotNumber, self->instancetype()", $self->instancetype());
	my $slots = $self->setSlotNumber($self->instancetype());
	$self->logDebug("slots", $slots); 

	my $pefile = $self->getQueuefile("pe-$pe");
	$self->logDebug("pefile", $pefile); 
	my $queuefile = $self->getQueuefile("queue-$queue");
	$self->logDebug("queuefile", $queuefile); 

	$self->addPE($pe, $pefile, $slots);

	$self->addPEToQueue($pe, $queue, $queuefile);

	$self->logDebug("Completed"); 
}

### QUEUE MONITOR
method setMonitor {
	$self->logCaller("");
	
	my $monitor = Agua::Monitor::SGE->new({
		conf		=>	$self->conf(),
		whoami		=>	$self->whoami(),
		pid			=>	$self->workflowpid(),
		db			=>	$self->db(),
		username	=>	$self->username(),
		project		=>	$self->project(),
		workflow	=>	$self->workflow(),
		cluster		=>	$self->cluster(),
		envars		=>	$self->envars(),

		logfile		=>	$self->logfile(),
		log		=>	$self->log(),
		printlog	=>	$self->printlog()
	});
	
	$self->monitor($monitor);
}
method updateMonitor {
	$self->logDebug("");
	$self->monitor()->load ({
		pid			=>	$self->workflowpid(),
		conf 		=>	$self->conf(),
		whoami		=>	$self->whoami(),
		db			=>	$self->db(),
		username	=>	$self->username(),
		project		=>	$self->project(),
		workflow	=>	$self->workflow(),
		cluster		=>	$self->cluster(),
		envars		=>	$self->envars(),
		logfile		=>	$self->logfile(),
		log			=>	$self->log(),
		printlog	=>	$self->printlog()
	});

	return $self->monitor();
}


#### STOP WORKFLOW
method stopWorkflow {
    $self->logDebug("");
    
	my $data         =	$self->data();

	#### SET EXECUTE WORKFLOW COMMAND
    my $bindir = $self->conf()->getKey("agua", 'INSTALLDIR') . "/cgi-bin";

    my $username = $data->{username};
    my $project = $data->{project};
    my $workflow = $data->{workflow};
	my $cluster = $data->{cluster};
	my $start = $data->{start};
    $start--;
    $self->logDebug("project", $project);
    $self->logDebug("start", $start);
    $self->logDebug("workflow", $workflow);
    
	#### GET ALL STAGES FOR THIS WORKFLOW
    my $query = qq{SELECT * FROM stage
WHERE username ='$username'
AND project = '$project'
AND workflow = '$workflow'
AND status='running'
ORDER BY number};
	$self->logDebug("$query");
	my $stages = $self->db()->queryhasharray($query);
	$self->logDebug("stages", $stages);

	#### EXIT IF NO PIDS
	$self->logError("No running stages in $project.$workflow") and return if not defined $stages;

	#### WARNING IF MORE THAN ONE STAGE RETURNED (SHOULD NOT HAPPEN 
	#### AS STAGES ARE EXECUTED CONSECUTIVELY)
	$self->logError("More than one running stage in $project.$workflow. Continuing with stopWorkflow") if scalar(@$stages) > 1;

	my $submit = $$stages[0]->{submit};
	$self->logDebug("submit", $submit);

	my $messages;
	if ( defined $submit and $submit ) {
		$self->logDebug("Doing killClusterJob(stages)");
		$messages = $self->killClusterJob($project, $workflow, $username, $cluster, $stages);
	}
	else {
		$self->logDebug("Doing killLocalJob(stages)");
		$messages = $self->killLocalJob($stages);
	}
	
	#### UPDATE STAGE STATUS TO 'stopped'
	my $update_query = qq{UPDATE stage
SET status = 'stopped'
WHERE username = '$username'
AND project = '$project'
AND workflow = '$workflow'
AND status = 'running'
};
	$self->logDebug("$update_query\n");
	my $success = $self->db()->do($update_query);

	$self->notifyError($data, "Could not update stages for $project.$workflow") if not $success;
	$data->{status}	=	"Updated stages for $project.$workflow";	
	$self->notifyStatus($data);
}

method killClusterJob ($project, $workflow, $username, $cluster, $stages) {
=head2

	SUBROUTINE		killClusterJob
	
	PURPOSE
	
		1. CANCEL THE JOB IDS OF ANY RUNNING STAGE OF THE WORKFLOW:
		
			1. IN THE CASE OF A SINGLE JOB, CANCEL THAT JOB ID
			
			2. IF AN APPLICATION IS RUNNING LOCALLY AND SUBMITTING JOBS TO THE
			
			CLUSTER, KILL ITS PROCESS ID AND CANCEL ANY JOBS IT HAS SUBMITTED
			
			(SHOULD BE REGISTERED IN THE stagejobs TABLE)

=cut
    $self->logDebug("Agua::Workflow::killClusterJob(stages)");
    
    $self->logDebug("stages", $stages);

        my $json         =	$self->json();
	
	foreach my $stage ( @$stages )
	{
		#### KILL PROCESS THAT SUBMITTED JOBS TO CLUSTER
		$self->killPid($stage->{workflowpid});
		#$self->killPid($stage->{stagepid});
	}

	#### DELETE THE QUEUE CONTAINING ALL JOBS FOR THIS WORKFLOW
	my $envars = $self->getEnvars($username, $cluster);
	$self->deleteQueue($project, $workflow, $username, $cluster, $envars);
}



method cancelJob ($jobid) {
=head2

	SUBROUTINE		cancelJob
	
	PURPOSE
	
		CANCEL A CLUSTER JOB BY JOB ID
		
=cut
	$self->logDebug("Agua::Workflow::cancelJob(jobid)");
	my $canceljob = $self->conf()->getKey("cluster", 'CANCELJOB');
	$self->logDebug("jobid", $jobid);
	
	my $command = "$canceljob $jobid";

	return `$command`;
}

method killLocalJob ($stages) {
#### 1. 'kill -9' THE PROCESS IDS OF ANY RUNNING STAGE OF THE WORKFLOW
#### 2. INCLUDES STAGE PID, App PARENT PID AND App CHILD PID)

    $self->logDebug("stages", $stages);
	my $messages = [];
	foreach my $stage ( @$stages )
	{
		#### OTHERWISE, KILL ALL PIDS
		push @$messages, $self->killPid($stage->{childpid}) if defined $stage->{childpid};
		push @$messages, $self->killPid($stage->{parentpid}) if defined $stage->{parentpid};
		push @$messages, $self->killPid($stage->{stagepid}) if defined $stage->{stagepid};
		push @$messages, $self->killPid($stage->{workflowpid}) if defined $stage->{workflowpid};
	}

	return $messages;
}

#### GET STATUS
method _getStatus ($username, $project, $workflow) {
=head2

SUBROUTINE	_getStatus

PURPOSE

 1. GET STATUS FROM stage TABLE
 2. GET STARCLUSTER STATUS IF CLUSTER IS RUNNING
 3. GET SGE QUEUE STATUS IF CLUSTER IS RUNNING
 4. UPDATE stage TABLE WITH JOB STATUS FROM QSTAT IF CLUSTER IS RUNNING
 5. RETURN VALUES FROM 1, 2 AND 3 IN A HASH

OUTPUT

	{
		stagestatus 	=> 	{
			project		=>	String,
			workflow	=>	String,
			stages		=>	HashArray,
			status		=>	String
		},
		clusterstatus	=>	{
			cluster		=>	String,
			status		=>	String,
			list		=>	String,
			log			=> 	String,
			balancer	=>	String
		},
		queuestatus		=>	{
			queue		=>	String,
			status		=>	String			
		}
	}

=cut

    $self->logDebug("username", $username);
    $self->logDebug("project", $project);
    $self->logDebug("workflow", $workflow);

	#### GET STAGES FROM stage TABLE
    my $query = qq{SELECT *, NOW() AS now
FROM stage
WHERE username ='$username'
AND project = '$project'
AND workflow = '$workflow'
ORDER BY number
};
	$self->logDebug("query", $query);
    my $stages = $self->db()->queryhasharray($query);
	#$self->logDebug("stages", $stages);
	
	#### QUIT IF stages NOT DEFINED
	$self->notifyError({}, "No stages with run status for username: $username, project: $project, workflow: $workflow") and return if not defined $stages;

	#### RETRIEVE CLUSTER INFO FROM clusterworkflow TABLE
	my $cluster = $self->getClusterByWorkflow($username, $project, $workflow);
	$self->logDebug("cluster", $cluster);
	$cluster = "" if not defined $cluster;
	$self->cluster($cluster);

    #### PRINT stages AND RETURN IF CLUSTER IS NOT DEFINED
	return $self->_getStatusLocal($username, $project, $workflow, $stages) if not $cluster;

	#### OTHERWISE, GET CLUSTER STATUS
	return $self->_getStatusCluster($username, $project, $workflow, $stages, $cluster);
}

method _getStatusCluster($username, $project, $workflow, $stages, $cluster) {
	$self->logDebug("");	

	#### GET WORKFLOW STATUS
	my $clusterworkflow = $self->getClusterWorkflow($username, $cluster, $project, $workflow);
	$self->logDebug("clusterworkflow", $clusterworkflow);
	my $workflowstatus = $self->getWorkflowStatus($username, $project, $workflow);	
	$self->logDebug("workflowstatus", $workflowstatus);

	#### SET DEFAULT VALUES
	my $stagestatus = {
		project		=>	$project,
		workflow	=>	$workflow,
		status		=>	$workflowstatus,
		stages		=>	$stages
	};
	
	#### SET EMPTY STATUS
	my $clusterstatus = $self->_emptyClusterStatus($cluster, "none");	
	my $queuestatus = $self->_emptyQueueStatus();
	
	my $status = {};
	$status->{stagestatus} 		= $stagestatus;
	$status->{clusterstatus} 	= $clusterstatus;
	$status->{queuestatus} 		= $queuestatus;
	
	#### RETURN EMPTY CLUSTER/QUEUE STATUS IF WORKFLOW IS EMPTY OR CLUSTER IS PENDING
	return $status if $workflowstatus eq "";

	#### GET CLUSTER STATUS
	my $currentstatus  =	$self->getClusterStatus($username, $cluster);
	$self->logDebug("currentstatus", $currentstatus);

	#### RETURN EMPTY CLUSTER/QUEUE STATUS IF NO CURRENT CLUSTER STATUS
	return $status if not defined $currentstatus;

	#### RETURN CURRENT CLUSTER STATUS AND EMPTY QUEUE STATUS
	#### IF CLUSTER IS PENDING
	$status->{clusterstatus} = $currentstatus;
	return $status if $currentstatus->{status} eq "cluster pending";

	#### CHECK IF CLUSTER IS RUNNING	
	my $starcluster 		= 	$self->loadStarCluster($username, $cluster);
	my $clusterrunning 		= 	$self->starcluster()->isRunning();
	$self->logDebug("clusterrunning", $clusterrunning);

	#### RETURN CURRENT CLUSTER STATUS AND EMPTY QUEUE STATUS
	#### IF CLUSTER IS NOT RUNNING
	return $status if not $clusterrunning;
	
	#### GET MASTER INFO
	my $masterinfo = $self->getHeadnodeMasterInfo($cluster);
	$self->logDebug("masterinfo", $masterinfo);
	return $status if not defined $masterinfo;
	
	### SET MASTER OPS SSH
	my $mastername	=	$masterinfo->{internalfqdn};
	$self->logDebug("mastername", $mastername);	
	$self->logDebug("DOING setMasterOpsSsh($mastername)");
	$self->setMasterOpsSsh($mastername);
	
	#### DETECT IF MASTER IS READY BY CONNECTING VIA SSH
	$self->logDebug("DOING masterConnect()");
	my $timeout = 10;
	my $masterconnect = $self->masterConnect($timeout);
	$self->logDebug("masterconnect", $masterconnect);
	
	#### REFRESH CLUSTER STATUS
	$clusterstatus = $self->clusterStatus();
	$self->logDebug("clusterstatus", $clusterstatus);
	
	#### IF CLUSTER IS RUNNING AND MASTER IS ACCESSIBLE,
	#### GET QUEUE STATUS
	if ( $clusterrunning and $masterconnect ) {
	
		#### GET qstat QUEUE STATUS FOR THIS USER'S PROJECT WORKFLOW
		my $monitor = $self->updateMonitor();
		$queuestatus = $monitor->queueStatus();
		$self->logDebug("queuestatus", $queuestatus);
	
		#### UPDATE stage TABLE WITH JOB STATUS FROM QSTAT
		$self->updateStageStatus($monitor, $stages);
	}	
	
	$status->{stagestatus} 		= $stagestatus;
	$status->{clusterstatus} 	= $clusterstatus;
	$status->{queuestatus} 		= $queuestatus;
	
	return $status;
}

method getWorkflowStatus ($username, $project, $workflow) {
	$self->logDebug("workflow", $workflow);

	my $object = $self->getWorkflow($username, $project, $workflow);
	$self->logDebug("object", $object);
	return if not defined $object;
	
	return $object->{status};
}

#### MASTER NODE METHODS
method masterConnect ($timeout) {
	$self->logDebug("timeout", $timeout);	
	my $command = "hostname";
	$self->logDebug("command", $command);
	my $connect = $self->master()->ops()->timeoutCommand($command, $timeout);
	$self->logDebug("connect", $connect);
	
	return 0 if not $connect;
	return 1;
}

method _getStatusLocal ($username, $project, $workflow, $stages) {
#### PRINT stages AND RETURN IF CLUSTER IS NOT DEFINED
#### I.E., JOB WAS SUBMITTED LOCALLY. 
#### NB: THE stage TABLE SHOULD BE UPDATED BY THE PROCESS ON EXIT.

	$self->logDebug("username", $username);
	
	my $workflowobject = $self->getWorkflow($username, $project, $workflow);
	#$self->logDebug("workflowobject", $workflowobject);
	my $status = $workflowobject->{status} || '';
	my $stagestatus 	= 	{
		project		=>	$project,
		workflow	=>	$workflow,
		stages		=>	$stages,
		status		=>	$status
	};
	#$self->logDebug("stagestatus", $stagestatus);
	
	my $clusterstatus 	=	$self->_emptyClusterStatus(undef, undef);
	$self->logDebug("clusterstatus", $clusterstatus);
	my $queuestatus		=	$self->_emptyQueueStatus();
	$self->logDebug("queuestatus", $queuestatus);
	
	return {
		stagestatus 	=> 	$stagestatus,
		clusterstatus	=>	$clusterstatus,
		queuestatus		=>	$queuestatus
	};	
}

method _emptyClusterStatus ($cluster, $status) {
	$cluster = "" if not defined $cluster;
	$status = "" if not defined $status;
	
	return {
		cluster		=> 	$cluster,
		status		=>	$status,
		list		=>	"NO CLUSTER OUTPUT",
		log			=> 	"NO CLUSTER OUTPUT",
		balancer	=>	""
	};
}

method _emptyQueueStatus {
	return {
		queue		=>	"NO QUEUE INFORMATION AVAILABLE",
		status		=>	""
	};
}

method updateStageStatus($monitor, $stages) {
#### UPDATE stage TABLE WITH JOB STATUS FROM QSTAT
	my $statusHash = $monitor->statusHash();
	$self->logDebug("statusHash", $statusHash);	
	foreach my $stage ( @$stages ) {
		my $stagejobid = $stage->{stagejobid};
		next if not defined $stagejobid or not $stagejobid;
		$self->logDebug("pid", $stagejobid);

		#### GET STATUS
		my $status;
		if ( defined $statusHash )
		{
			$status = $statusHash->{$stagejobid};
			next if not defined $status;
			$self->logDebug("status", $status);

			#### SET TIME ENTRY TO BE UPDATED
			my $datetime = "queued";
			$datetime = "started" if defined $status and $status eq "running";

			$datetime = "completed" if not defined $status;
			$status = "completed" if not defined $status;
		
			#### UPDATE THE STAGE ENTRY IF THE STATUS HAS CHANGED
			if ( $status ne $stage->{status} )
			{
				my $query = qq{UPDATE stage
SET status='$status',
$datetime=NOW()
WHERE username ='$stage->{username}'
AND project = '$stage->{project}'
AND workflow = '$stage->{workflow}'
AND number='$stage->{number}'};
				$self->logDebug("$query");
				my $result = $self->db()->do($query);
				$self->logDebug("status update result", $result);
			}
		}
	}	
}

method clusterStatus {
	$self->logDebug("");
	my $username = $self->username();
	my $cluster = $self->cluster();
	$self->logError("cluster not defined") and return if not $cluster;
	
	#### LOAD STARCLUSTER
	$self->loadStarCluster($username, $cluster) if not $self->starcluster()->loaded();
	my $clusterlines = 20;
	my $balancerlog = $self->starcluster()->balancerLog($clusterlines);
	my $clusterlog = $self->starcluster()->clusterLog($clusterlines);
	
	#### GET CLUSTER LIST
	my $configfile	=	$self->setConfigFile($username, $cluster);
	my $command = "starcluster -c $configfile listclusters $cluster";
	$self->logDebug("command", $command);
	my ($clusterlist) = $self->head()->ops()->runCommand($command);
	my $status = "unknown";
	if ( $clusterlist =~ /Cluster nodes:\s+master\s+(\S+)/ ) {
		$status = $1;
	}

	my $clusterstatus = {
		cluster		=>	$cluster,
		status		=>	$status,
		list		=>	$clusterlist,
		log			=>	$clusterlog,
		balancer	=>	$balancerlog,
	};
	
	return $clusterstatus;
}

#### UPDATE
method updateWorkflowStatus ($username, $cluster, $project, $workflow, $status) {
	$self->logDebug("status", $status);

	my $table ="workflow";
	my $hash = {
		username	=>	$username,
		cluster		=>	$cluster,
		project		=>	$project,
		name		=>	$workflow,
		status		=>	$status,
	};
	$self->logDebug("hash", $hash);
	my $required_fields = ["username", "project", "name"];
	my $set_hash = {
		status		=>	$status
	};
	my $set_fields = ["status"];
	
	my $success = $self->db()->_updateTable($table, $hash, $required_fields, $set_hash, $set_fields);
	#$self->logDebug("success", $success);
	
	return $success;
}

method updateClusterWorkflow ($username, $cluster, $project, $workflow, $status) {
 	$self->logDebug("");

	my $query = qq{SELECT * FROM clusterworkflow
WHERE username='$username'
AND project='$project'
AND workflow='$workflow'};
	$self->logDebug("$query");
	my $exists = $self->db()->query($query);
	$self->logDebug("clusterworkflow entry exists", $exists);

	#### SET STATUS
	my $success;
	if ( defined $exists ) {
		$query = qq{UPDATE clusterworkflow
SET status='$status'
WHERE username='$username'
AND project='$project'
AND workflow='$workflow'};
		$self->logDebug("$query");
		$success = $self->db()->do($query);
	}
	else {
		my $object = {
			status		=>	$status,
			username	=>	$username,
			cluster		=>	$cluster,
			project		=>	$project,
			workflow	=>	$workflow
		};

		#### DO THE ADD
		my $required_fields = [ "username", "project", "workflow" ];
		my $inserted_fields = $self->db()->fields("clusterworkflow");
		$success = $self->_addToTable("clusterworkflow", $object, $required_fields, $inserted_fields);
		$self->logDebug("insert success", $success)  if defined $success;

		my $success = $self->db()->do($query);
	}

	return 1 if defined $success and $success;
	return 0;
}

method updateClusterPid ($username, $cluster, $pid) {
	$self->logDebug("pid", $pid);
	#### CHANGE STATUS TO COMPLETED IN clusterstatus TABLE
	
	my $query = qq{UPDATE clusterstatus
SET pid='$pid'
WHERE username='$username'
AND cluster='$cluster'};
	my $success = $self->db()->do($query);
	return 1 if defined $success and $success;
	return 0;
}

method updateClusterStatus ($username, $cluster, $status) {
 	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	$self->logDebug("status", $status);
	
	my $query = qq{SELECT 1 FROM clusterstatus
WHERE username='$username'
AND cluster='$cluster'};
	$self->logDebug("$query");
	my $exists = $self->db()->query($query);
	$self->logDebug("clusterstatus entry exists", $exists);

	#### SET STATUS
	my $now = $self->db()->now();
	my $success;
	if ( defined $exists ) {
		$query = qq{UPDATE clusterstatus
SET polled=$now,
status='$status'
WHERE username='$username'
AND cluster='$cluster'};
		$self->logDebug("$query");
		$success = $self->db()->do($query);
	}
	else {
		$query = qq{SELECT *
FROM cluster
WHERE username='$username'
AND cluster='$cluster'};
		$self->logDebug("$query");
		my $object = $self->db()->queryhash($query);
		$object->{started} = $now;
		$object->{polled} = $now;
		$object->{status} = $status;
		
		my $required = ["username", "cluster"];
		my $required_fields = ["username", "cluster"];
	
		#### CHECK REQUIRED FIELDS ARE DEFINED
		my $not_defined = $self->db()->notDefined($object, $required_fields);
		$self->logError("undefined values: @$not_defined") and return if @$not_defined;
	
		#### DO THE ADD
		my $inserted_fields = $self->db()->fields("clusterstatus");
		$success = $self->_addToTable("clusterstatus", $object, $required_fields, $inserted_fields);
		#$self->logDebug("insert success", $success)  if defined $success;
	}

	return 1 if defined $success and $success;
	return 0;
}

#### START BALANCER
method startBalancer ($clusterobject) {
    $self->logDebug("Workflow::startBalancer(clusterobject)");
    $self->logDebug("clusterobject", $clusterobject);
	
    my $username    = $self->username();
    my $cluster    = $self->cluster();
    
	my $starcluster = $self->loadStarCluster($username, $cluster);
	$starcluster->launchBalancer();
}

#### STOP CLUSTER
method stopCluster {
	$self->logDebug("Agua::Workflow::stopCluster()");

    my $data        =	$self->data();
	my $username 	=	$data->{username};
	my $cluster 	=	$data->{cluster};

	$self->logDebug("cluster", $data->{cluster});
	$self->logDebug("username", $data->{username});

	$self->logDebug("Doing starcluster = StarCluster->new(data)");
	my $starcluster = $self->loadStarCluster($username, $cluster);

	$self->logError("Cluster $cluster is not running: $cluster") and return if not $starcluster->isRunning();
	
	$self->logDebug("Doing StarCluster->stop()");
	my $success		=	$starcluster->stopCluster();
	
	$self->notifyStatus($data, "Stopped cluster $cluster") if $success;
	$self->notifyError($data, "Failed to stop cluster $cluster") if not $success;	
}

#### START CLUSTER
method startCluster {
	my $username 	=	$self->username();
	my $cluster 	=	$self->cluster();
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	
	$self->logDebug("Doing self->loadStarCluster()");
	my $starcluster = $self->loadStarCluster($username, $cluster);

	$self->logError("Cluster $cluster is already running: $cluster") and return if $starcluster->isRunning();
	
	$self->logDebug("Doing StarCluster->start()");
	my $started = $starcluster->startCluster();
	
	$self->logError("Failed to start cluster", $cluster) and return if not $started;
	$self->logStatus("Started cluster", $cluster);
}

#### ADD AWS INFORMATION
method addAws {
#### SAVE USER'S AWS AUTHENTICATION INFORMATION TO aws TABLE
	my $username 	= 	$self->username();
    my $data 		=	$self->data();
	$self->logDebug("username", $username);
	$self->logDebug("data", $data);
    
	my $clusterrunning = $self->clusterWorkflowIsRunning($username);
	$self->logDebug("clusterrunning", $clusterrunning);

	$self->notifyError($data, "Can't add AWS credentials (and regenerate keypair file) while any clusters are running. Please stop all running workflows then retry") if $clusterrunning;

	#### REMOVE 
	$self->_removeAws({username => $username});

	#### ADD TO TABLE
	my $success = $self->_addAws($data);
 	$self->notifyError($data, "Failed to add AWS table entry") and return if not $success;

	##### REMOVE WHITESPACE
	$data->{ec2publiccert} =~ s/\s+//g;
	$data->{ec2privatekey} =~ s/\s+//g;
	
	#### PRINT KEY FILES
	$self->logDebug("DOING self->printKeyFiles()");
	my $privatekey	=	$data->{ec2privatekey};
	my $publiccert	=	$data->{ec2publiccert};
	$self->printEc2KeyFiles($username, $privatekey, $publiccert);
	
	#### GENERATE KEYPAIR FILE FROM KEYS
	$self->logDebug("Doing self->generateClusterKeypair()");
	$success	=	$self->generateClusterKeypair();
	
 	$self->notifyStatus($data, "Added AWS credentials") if $success;
 	$self->notifyError($data, "Failed to add AWS credentials") if not $success;
}

method clusterWorkflowIsRunning ($username) {
	my $query = qq{SELECT 1 from clusterworkflow
WHERE username='$username'
AND status='running'};
	$self->logDebug("query", $query);
    my $result =  $self->db()->query($query);
	$self->logDebug("result", $result);
	
	return 0 if not defined $result or not $result;
	return 1;
}
#### STARCLUSTER KEYS
method generateClusterKeypair {
	$self->logDebug("");
	
	my $username 		=	$self->username();
	my $login 			=	$self->login();
	my $hubtype 		=	$self->hubtype();
	$self->logDebug("username", $username);
	$self->logDebug("login", $login);
	$self->logDebug("hubtype", $hubtype);

	#### SET KEYNAME
	my $keyname 		= 	"$username-key";
	$self->logDebug("keyname", $keyname);

	#### SET PRIVATE KEY AND PUBLIC CERT FILE LOCATIONS	
	my $privatekey	=	$self->getEc2PrivateFile($username);
	my $publiccert 	= 	$self->getEc2PublicFile($username);

	$self->logDebug("privatekey", $privatekey);
	$self->logDebug("publiccert", $publiccert);

    #### SET STARCLUSTER	
	my $starcluster = $self->starcluster();
	$starcluster = $self->starcluster()->load(
		{
			privatekey	=>	$privatekey,
			publiccert	=>	$publiccert,
			username	=>	$username,
			keyname		=>	$keyname,
			conf		=>	$self->conf(),
			log			=>	$self->log(),
			printlog	=>	$self->printlog(),
			logfile		=>	$self->logfile()
		}
	) if not $self->starcluster()->loaded();
	
	#### GENERATE KEYPAIR FILE IN .starcluster DIR
	$self->logDebug("Doing starcluster->generateKeypair()");
	return $starcluster->generateKeypair();
}

### NEW/ADD CLUSTER
method newCluster {
#### CREATE NEW CELL DIR
	my $username 	=	$self->username();
	my $cluster 	=	$self->cluster();
	$self->logDebug("username", $username);
	$self->logDebug("cluster", $cluster);
	
	#### CREATE DIR
	$self->_newCluster($username, $cluster);
}

method _newCluster ($username, $cluster) {
	#$self->logError("Cluster $cluster already exists") and return if $self->_isCluster($username, $cluster);
	my $success = $self->_addCluster();
	#$self->logError("Could not add cluster $json->{cluster} into cluster table. Returning") and return if not defined $success or not $success;

	$self->setSgePorts();
	
	#### ENSURE DB HANDLE STAYS ALIVE
	$self->setDbh();

	#### CREATE CELLDIR
	$self->logDebug("Creating celldir");
	$self->_createCellDir($username, $cluster);	

	#### CREATE STARCLUSTER config FILE
	my $scheduler	=	$self->conf()->getKey("scheduler", undef);
	$self->logDebug("scheduler", $scheduler);
	if ( $scheduler eq "starcluster" ) {
		$self->logDebug("Creating configfile");
		$self->createConfigFile($username, $cluster);	
	}	
}

method addCluster {
#### MODIFY EXISTING CLUSTER. DO NOT CREATE NEW CELL DIR
 	$self->logDebug("");
    my $data 		=	$self->data();
	my $username 	=	$self->data()->{username};
	my $cluster 	=	$data->{cluster};

	$self->_removeCluster();	
	my $success = $self->_addCluster();
	return if not defined $success;
	$self->logStatus("Could not add cluster $data->{cluster}") and return if not $success;

	#### FORK: PARENT MESSAGES AND QUITS, CHILD DOES THE WORK
	if ( my $child_pid = fork() ) {
		#### PARENT EXITS
	
		#### SET InactiveDestroy ON DATABASE HANDLE
		$self->db()->dbh()->{InactiveDestroy} = 1;
		my $dbh = $self->db()->dbh();
		undef $dbh;
	
		$self->logStatus("Updated cluster $data->{cluster}");
		#exit(0);
	}
	else
	{
		#### CHILD CONTINUES THE JOB
	
		#### CLOSE OUTPUT SO CGI SCRIPT WILL QUIT
		close(STDOUT);  
		close(STDERR);
		close(STDIN);
		
		#### ENSURE DB HANDLE STAYS ALIVE
		$self->setDbh();
	
		#### CREATE STARCLUSTER config FILE
		$self->logDebug("Doing     self->createConfigFile($username, $cluster)");
		$self->createConfigFile($username, $cluster);

		$self->notifyStatus($data, "Updated cluster $data->{cluster}");
		exit;
	}
}

method createConfigFile ($username, $cluster) {
	$self->logDebug("");
	
	#### LOAD STARCLUSTER IF NOT LOADED
	$self->loadStarCluster($username, $cluster) if not $self->starcluster()->loaded();
	
	#### SET UNIQUE WORKFLOW
	$self->starcluster()->project($self->project());
	$self->starcluster()->workflow($self->workflow());

	#### CREATE CONFIG FILE
	$self->starcluster()->createConfig();
}


#### SET OPS
method setHead {
	my $instance = Agua::Instance->new({
		conf		=>	$self->conf(),
		log		=>	$self->log(),
		printlog	=>	$self->printlog()
	});

	$self->head($instance);	
}

method setMaster {
	my $instance = Agua::Instance->new({
		conf		=>	$self->conf(),
		log		=>	$self->log(),
		printlog	=>	$self->printlog()
	});

	$self->master($instance);	
}

#### SET VIRTUALISATION PLATFORM
method setVirtual {
	my $virtualtype		=	$self->conf()->getKey("agua", "VIRTUALTYPE");
	$self->logDebug("virtualtype", $virtualtype);

	#### RETURN IF TYPE NOT SUPPORTED	
	$self->logDebug("virtualtype not supported: $virtualtype") and return if $virtualtype !~	/^(openstack|vagrant)$/;

   #### CREATE DB OBJECT USING DBASE FACTORY
    my $virtual = Virtual->new( $virtualtype,
        {
			conf		=>	$self->conf(),
            username	=>  $self->username(),
			
			logfile		=>	$self->logfile(),
			log			=>	$self->log(),
			printlog	=>	$self->printlog()
        }
    ) or die "Can't create virtualtype: $virtualtype. $!\n";
	$self->logDebug("virtual: $virtual");

	$self->virtual($virtual);
}


#### SET WHOAMI
method setWhoami {
	my $whoami	=	`whoami`;
	$whoami		=~	s/\s+$//;
	$self->logDebug("whoami", $whoami);
	
	return $whoami;
}

#
}	#### Agua::Workflow
