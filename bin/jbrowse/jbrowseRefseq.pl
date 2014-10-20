#!/usr/bin/perl -w

#### DEBUG
my $DEBUG = 0;
#$DEBUG = 1;

#### TIME
my $time = time();

=head2

    APPLICATION     jbrowseRefseq
	    
    PURPOSE
  
		CREATE A refSeqs.js JSON FILE CONTAINING ENTRIES FOR ALL CHROMOSOMES
		
		IN THE REFERENCE GENOME

    INPUT

			1. chromosome-sizes.txt FILE GENERATED BY chromosomeSizes.pl
			
			2. CHUNK SIZE FOR GENERATING FEATURES
			
			3. OUTPUT DIRECTORY
			
    OUTPUT
    
        1. OUTPUT FILE refSeqs.js IN OUTPUT DIRECTORY
        
		refSeqs =
		[
		   {
			  "length" : 247249719,
			  "name" : "chr1",
			  "seqDir" : "data/seq/chr1",
			  "seqChunkSize" : 20000,
			  "end" : 247249719,
			  "start" : 0
		   }
		   ,
		   {
			  "length" : 242951149,
			  "name" : "chr2",
			  "seqDir" : "data/seq/chr2",
			  "seqChunkSize" : 20000,
			  "end" : 242951149,
			  "start" : 0
		   }
		   ,
		   
		]

    USAGE
    
	./jbrowseRefseq.pl <--inputfiles String> <--outputdir String>
        <--inputdir String> [--splitfile String] [--reads Integer] [--convert]
        [--clean] [--queue String] [--maxjobs Integer] [--cpus Integer] [--help]

    --outputdir       :   Directory with one subdirectory per reference chromosome
                            containing an out.sam or out.bam alignment output file
    --inputdir    :   Location of directory containing chr*.fa reference files
    --chromodir         :   Name of the reference chromodir (e.g., 'mouse')
    --queue           :   Cluster queue name
    --cluster         :   Cluster type (LSF|PBS)
    --help            :   print help info
    

	NOTES
	
		refSeqs =
		[
		   {
			  "length" : 247249719,
			  "name" : "chr1",
			  "seqDir" : "data/seq/chr1",
			  "seqChunkSize" : 20000,
			  "end" : 247249719,
			  "start" : 0
		   }
		   ,
		   {
			  "length" : 242951149,
			  "name" : "chr2",
			  "seqDir" : "data/seq/chr2",
			  "seqChunkSize" : 20000,
			  "end" : 242951149,
			  "start" : 0
		   }
		   ,
		   
		]

	EXAMPLES

/agua/bin/jbrowse/jbrowseRefseq.pl \
--inputdir /data/sequence/reference/human/hg19/fasta \
--outputdir /tmp/jbrowse \
--chunksize 20000


=cut

use strict;

#### EXTERNAL MODULES
use Term::ANSIColor qw(:constants);
use Data::Dumper;
use Getopt::Long;
use FindBin qw($Bin);

#### USE LIBRARY
use lib "$Bin/../../lib";
use lib "$Bin/../../lib/external/lib/perl5";	

#### INTERNAL MODULES
use Agua::JBrowse;
use Timer;
use Util;
use Conf::Yaml;

##### STORE ARGUMENTS TO PRINT TO FILE LATER
my @arguments = @ARGV;
unshift @arguments, $0;

#### FLUSH BUFFER
$| =1;

#### SET CONF
my $conf = Conf::Yaml->new(inputfile=>"$Bin/../../conf/config.yaml");

#### GET OPTIONS
my $inputdir;
my $outputdir;
my $chunksize;
my $chromofile;
my $help;
print "jbrowseRefseq.pl    Use option --help for usage instructions.\n" and exit if not GetOptions (	
	'inputdir=s'	=> \$inputdir,
	'outputdir=s'	=> \$outputdir,
    'chromofile=s' 	=> \$chromofile,
    'chunksize=i' 	=> \$chunksize,
    'help' 			=> \$help
);

#### PRINT HELP
if ( defined $help )	{	usage();	}

#### CHECK INPUTS
die "outputdir not defined (Use --help for usage)\n" if not defined $outputdir;
die "neither chromofile nor inputdir defined (Use --help for usage)\n" if not defined $chromofile and not defined $inputdir;
die "chunksize not defined (Use --help for usage)\n" if not defined $chunksize;

#### IGNORE CHROMOFILE IF INPUT DIR DEFINED
print "Ignoring chromofile because inputdir is defined: $inputdir\n";
$chromofile = undef if defined $inputdir and defined $chromofile;

#### CHECK INPUT DIR
print "Can't find inputdir: $inputdir\n" and exit if not -d $inputdir;

#### DEBUG
print "jbrowseRefseq.pl    outputdir: $outputdir\n" if $DEBUG;
print "jbrowseRefseq.pl    inputdir: $inputdir\n" if $DEBUG;
print "jbrowseRefseq.pl    chromofile: $chromofile\n" if $DEBUG;
print "jbrowseRefseq.pl    chunksize: $chunksize\n" if $DEBUG;

#### INSTANTIATE Agua::JBrowse OBJECT
my $jbrowseObject = Agua::JBrowse->new({	conf	=>	$conf	});

#### GENERATE FEATURES
if ( defined $inputdir ) {
	$jbrowseObject->generateReference($inputdir, $outputdir, $chunksize);
}
else {
	$jbrowseObject->createRefseqFile($outputdir, $chromofile, $chunksize);
}

#### PRINT RUN TIME
my $runtime = Timer::runtime( $time, time() );
print "jbrowseRefseq.pl    Run time: $runtime\n";
print "jbrowseRefseq.pl    Completed $0\n";
print "jbrowseRefseq.pl    ";
print Timer::current_datetime(), "\n";
print "jbrowseRefseq.pl    ****************************************\n\n\n";
exit;

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#									SUBROUTINES
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


sub usage
{
	print GREEN;
	print `perldoc $0`;
	print RESET;
	exit;
}

