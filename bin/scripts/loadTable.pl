#!/usr/bin/perl -w
use strict;

#### DEBUG
my $DEBUG = 0;
#$DEBUG = 1;


=head2

    NAME		loadTable
    
    PURPOSE
	
		LOAD A .TSV FILE INTO A DATABASE TABLE 

    INPUT
	
		1. DATABASE NAME
		
		2. TABLE NAME

		2. LOCATION OF .TSV FILE

    OUTPUT
	
		1. POPULATED ROWS IN DATABASE TABLE

    USAGE
	
		./loadTable.pl <--db String> <--table String> <--tsvfile String> [-h] 

    --db          :   Name of database
    --table		  :   Name of table
    --tsvfile	  :   Location of *.tsv file
    --help        :   print this help message

	< option > denotes REQUIRED argument
	[ option ] denotes OPTIONAL argument

    EXAMPLE

perl loadTable.pl --db agua --table samplefile --tsvfile /agua/apps/cu/data/samplefile.tsv

=cut

#### TIME
my $time = time();

#### USE LIBS
use FindBin qw($Bin);
use lib "$Bin/../../lib";

#### INTERNAL MODULES
use Agua::Configure;
use Agua::DBaseFactory;
use Timer;
use Util;
use Conf::Yaml;

#### EXTERNAL MODULES
use Data::Dumper;
use File::Path;
use File::Copy;
use Getopt::Long;

#### SET LOG
my $logfile 	= 	"/tmp/loadtable.$$.log";
my $log 		= 	2;
my $printlog 	= 	5;


#### GET OPTIONS
my $db;
my $table;
my $tsvfile;	
my $help;
GetOptions (
	'db=s'			=> \$db,
	'table=s' 		=> \$table,
	'tsvfile=s' 	=> \$tsvfile,

	'log=s'			=> \$log,
	'printlog=s' 	=> \$printlog,

	'help' => \$help) or die "No options specified. Try '--help'\n";
if ( defined $help )	{	usage();	}

#### FLUSH BUFFER
$| =1;

#### CHECK INPUTS
die "Database not defined (option --db)\n" if not defined $db;
die "Table not defined (option --table)\n" if not defined $table;
die "Output directory not defined (option --tsvfile)\n" if not defined $tsvfile; 

#### GET CONF
my $configfile = "$Bin/../../conf/config.yaml";
my $conf = Conf::Yaml->new({
	inputfile 	=> $configfile,
	logfile		=>	$logfile,
	log			=>	$log,
	printlog	=>	$printlog
});

#### CREATE OUTPUT DIRECTORY
my ($outputdir)	=	$tsvfile	=~	/^(.+?)\/[^\/]+$/;
File::Path::mkpath($outputdir) if not -d $outputdir;
die "Can't create output directory: $outputdir\n" if not -d $outputdir;

my $object = Agua::Configure->new({
	conf		=>	$conf,
	database	=>	$db,
	configfile	=>	$configfile,
	logfile		=>	$logfile,
	log			=>	$log,
	printlog	=>	$printlog
});

$object->setDbh();
$object->db()->load($table, $tsvfile, undef);

#### PRINT RUN TIME
my $runtime = Timer::runtime( $time, time() );
print "\n";
print "loadTable.pl    Run time: $runtime\n";
print "loadTable.pl    Completed $0\n";
print Util::datetime(), "\n";
print "loadTable.pl    ****************************************\n\n\n";
exit;

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#									SUBROUTINES
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


sub usage
{
    print `perldoc $0`;
	exit;
}
