package Agua::Install;

=head2

=head3 PACKAGE		Agua::PreInstall

=head3 PURPOSE
    
	1. INSTALL THE DEPENDENCIES FOR Agua
	
	2. CREATE THE REQUIRED DIRECTORY STRUCTURE

	<INSTALLDIR>/bin
				cgi-bin  --> /var/www/cgi-bin/<URLPREFIX>
				   conf --> <INSTALLDIR>/conf
				   lib --> <INSTALLDIR>/lib
				   sql --> <INSTALLDIR>/bin/sql
				conf
				html --> /var/www/html/<URLPREFIX>
				lib
				t

=head3 LICENCE

This code is released under the MIT license, a copy of which should
be provided with the code.

=end pod

=cut

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw();
our $AUTOLOAD;

#### EXTERNAL MODULES
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/lib";
use File::Path;

#### INTERNAL MODULES
#use Conf::Yaml;


sub new {
 	my $class 		=	shift;
	my $arguments 	=	shift;
        
	my $self = {};
    bless $self, $class;

    return $self;
}

sub run {
    my $self	=	shift;

    #### UPDATE APT-get
    $self->updateAptGet();
    
    #### INSTALL CURL
    $self->installPackage("curl");

    #### INSTALL PERL MODS
    $self->installPerlMods();
    
    #### COPY CONFIG FILE
    $self->copyConf();

    #### INSTALL MYSQL
    $self->installMysql();    
}

sub updateAptGet {
    print "Installer::updateAptGet\n";
    my $self		=	shift;

	my $arch 	=	$self->getArch();
	if ( $arch eq "ubuntu" ) {
		$self->runCommands([
			"rm -fr /var/lib/apt/lists/lock"
			, "apt-get update"
			#, "apt-get upgrade -y"
		]);
	}	
}

sub installPackage  {
    my $self		=	shift;
    my $package     =   shift;

    print "Agua::PreInstall::installPackage    Agua::PreInstall::installPackage(package)\n";
    return 0 if not defined $package or not $package;
    print "Agua::PreInstall::installPackage    package: $package\n";
    
    if ( -f "/usr/bin/apt-get" )
    {
    	$self->runCommands([
    	"rm -fr /var/lib/dpkg/lock",
    	"dpkg --configure -a",
    	"rm -fr /var/cache/apt/archives/lock"
    	]);

    	$ENV{'DEBIAN_FRONTEND'} = "noninteractive";
    	my $command = "/usr/bin/apt-get -q -y install $package";
    	print "Agua::PreInstall::installPackage    command: $command\n";
    	system($command);
    }
    elsif ( -f "/usr/bin/yum" )
    {
		my $commands = [
			"rm -fr /var/run/yum.pid", 
			"/usr/bin/yum -y install $package"
		];
    	$self->runCommands($commands);
    	print "Agua::PreInstall::installPackage    commands:\n";
		print join "\n", @$commands;
		print "\n";
    }    
}

sub installPuppet {
	my $self		=	shift;
	
	my $puppetfile	=	"$Bin/resources/puppet/Puppetfile";
	`ln -s $puppetfile /etc/puppet/Puppetfile`;
	
	my $architecture	=	$self->getArch();
	print "Agua::PreInstall::installPuppet    architecture: $architecture\n";
	
	my $bootstrap	=	"$Bin/resources/puppet/bootstrap/$architecture.sh";
	print "Agua::PreInstall::installPuppet    $bootstrap\n";
	
	if ( $bootstrap eq "" ) {
		print "Agua::PreInstall::installPuppet    Unsupported architecture. Exiting\n";
		exit;
	}
	
	print "Agua::PreInstall::installPuppet    Installing the latest version of puppet\n";
	`chmod 755 $bootstrap`;
	print `$bootstrap`;
	
	return;
}

sub installCpanMinus {
	my $self		=	shift;
	
	my $commands	=	[
		"cd /opt/; curl https://raw.github.com/miyagawa/cpanminus/master/cpanm > cpanm",
		"chmod +x /opt/cpanm",
		"ln -s /opt/cpanm /usr/bin/",
		#"curl -L http://cpanmin.us | perl - App::cpanminus"
	];
	print "Agua::PreInstall::installCpanMinus    commands:\n";
	print Dumper $commands;
	
	$self->runCommands($commands);
}


sub copyConf {
	my $self		=	shift;

	#### COPY config.yaml FILE FROM RESOURCES TO conf DIR
	#### SKIP IF TARGET FILE ALREADY EXISTS
    my $confdir 	= 	"$Bin/../../conf";
    my $resourcedir = 	"$Bin/resources/agua/conf";
    my $sourcefile 	= 	"$resourcedir/config.yaml";
    my $targetfile 	= 	"$confdir/config.yaml";
	print "targetfile: $targetfile\n";
	
    return if -f $targetfile;
	
    #### COPY
    my $command = "cp -f $sourcefile $targetfile";
	print "command: $command\n";
    `$command`;
}

sub installPerlMods {
    my $self		=	shift;

	#### CPANM
	$self->installCpanMinus();
	
	my $arch	=	$self->getArch();

	#### centos
	if ( $arch eq "centos" ) {
		#### BUILD TOOLS
		$self->installPackage("gcc gcc-c++ make automake kernel-devel");

		#### FOR ExtUtils::MakeMaker
		$self->installPackage("perl-devel");

		#### FOR XML::Parser
		$self->installPackage("expat");

		#### FOR LWP
		$self->installPackage("zlib.i686");
		$self->installPackage("zlib-devel.i686");

		#### FOR Net::RabbitFoot DEPENDENCY XML::LibXML
		$self->installPackage("libxml2");
		$self->installPackage("libxml2-devel");
		$self->installPackage("libxml2-devel.i686");
		
		#### FOR mysql_config
		$self->installPackage("mysql-devel");
	}
	#### ubuntu
	elsif ( $arch eq "ubuntu" ) {
		#### BUILD TOOLS
		$self->installPackage("build-essential");

		#### PERL DOC
		$self->installPackage("perl-doc");

		#### FOR XML::Parser
		$self->installPackage("expat-dev");

		#### FOR LWP
		$self->installPackage("zlib1g");
		$self->installPackage("zlib1g-dev");
	
		#### FOR Net::RabbitFoot DEPENDENCY XML::LibXML
		$self->installPackage("libxml2");
		$self->installPackage("libxml2-dev");
	
		#### FOR mysql_config
		$self->installPackage("libmysql++-dev");
	}
	else {
		print "Agua::PreInstall::installPerlMods    architecture not supported: $arch\n";
	}

	my $perlmodsfile	=	"$Bin/resources/agua/perlmods";
    print "Agua::PreInstall::installPerlMods    perlmodsfile: $perlmodsfile\n";
    my $contents = $self->fileContents($perlmodsfile);
    print "Agua::PreInstall::installPerlMods    perlmodsfile is empty: $perlmodsfile\n" if not defined $contents or not $contents;
    
    #### INSTALL MODULES IN LIST
    my @modules = split "\n", $contents;
    foreach my $module ( @modules ) {
        next if $module =~ /^#/;
		next if $module =~ /^\s*$/;
		print "Agua::PreInstall::installPerlMods    installing module: $module\n";
    	print "Agua::PreInstall::installPerlMods    Problem installing module: '$module'\n" if not $self->cpanminusInstall($module);
    }
}

sub runCommands {
    my $self		=	shift;
    my $commands 	=	shift;
    print "Agua::PreInstall::runCommands    Agua::PreInstall::runCommands(commands)\n";
    foreach my $command ( @$commands )
    {
    	print "Agua::PreInstall::runCommands    command: $command\n";		
    	print `$command` or die("Error with command: $command\n$! , stopped");
    }
}
sub fileContents {
    my $self		=	shift;
    my $file		=	shift;

    print "Agua::PreInstall::contents    Agua::PreInstall::fileContents(file)\n";
    print "Agua::PreInstall::contents    file: $file\n";

    die("Agua::PreInstall::contents    file not defined\n") if not defined $file;
    die("Agua::PreInstall::contents    Can't find file: $file\n$!") if not -f $file;


    my $temp = $/;
    $/ = undef;
    open(FILE, $file) or die("Can't open file: $file\n$!");
    my $contents = <FILE>;
    close(FILE);
    $/ = $temp;
    
    return $contents;
}

sub cpanminusInstall {
        my $self		=	shift;
        my $module 		=    shift;
        return 0 if not defined $module or not $module;
        
		my $cpanm = "/usr/local/bin/cpanm";
		$cpanm = "/usr/bin/cpanm" if not -f $cpanm;
		my $command = "$cpanm $module";
		
        print `$command`;
}



#### MYSQL
sub installMysql {
	my $self		=	shift;

	#### INSTALL MYSQL
    print "Agua::Install::installMysql    Installing MySQL\n";
	$self->installPackage("mysql-server");
	$self->installPackage("mysql-client");

	#### EDIT CONFIG
    print "Agua::Install::installMysql    Editing MySQL config\n";
	$self->editMysqlConfig();

	#### MAKE MYSQL START AT BOOT
    print "Agua::Install::installMysql    Enabling MySQL start on boot\n";
	$self->mysqlBootStart();
}

sub mysqlBootStart {
	my $self		=	shift;
	print "Agua::Install::mysqlBootStart    Enabling mysql start on boot\n";
	
	#### GET ARCHITECTURE
	my $arch = $self->getArch();
	print "Agua::Install::mysqlBootStart    arch: $arch\n";

	#### REPLACE /etc/init.d/mysqld
	my $installdir	=	"/agua";
	$self->replaceFile("/etc/init.d/mysqld", "/etc/init.d/mysqld.bkp", 0);
	$self->replaceFile("/etc/init.d/mysqld", "$installdir/bin/install/resources/mysql/init.d/mysqld", 1);
	$self->runCommands(["chmod 755 /etc/init.d/mysqld"]);


#    ##### START MYSQL AUTOMATICALLY AT BOOT
#    my $command = "sudo /sbin/chkconfig --level 2345 mysqld on";
#	#$command = "update-rc.d -f mysql defaults" if $arch eq "ubuntu";
#	$self->runCommands([$command]);

}

sub editMysqlConfig {
	my $self		=	shift;
    print "Agua::Install::editMysqlConfig    Editing mysql config\n";

	#### GET ARCHITECTURE
	my $arch = $self->getArch();
	print "Agua::Install::editMysqlConfig    arch: $arch\n";

    my $configfile = "/etc/mysql/my.cnf";
	$configfile = "/etc/my.cnf" if $arch eq "centos";

	#### BACKUP FILE
	my $backupfile 	=	$self->incrementFile($configfile);
	print "backupfile: $backupfile\n";
	my $force = 1;
	$self->backupFile($configfile, $backupfile, $force);
	
	require Conf::Ini;
	my $config = Conf::Ini->new({
		inputfile	=>	$configfile,
		separator	=>	"=",
		#log		=>	5
	});
	
	$config->setKey("mysqld", "local-infile", 1);
	$config->setKey("mysql", "local-infile", 1);
	
    #### RESTART MYSQL
	my $restart = "service mysqld restart";
	$restart = "service mysql restart" if $arch eq "ubuntu";
    $self->runCommands([$restart]);
}

sub createDir {
	my $self		=	shift;
	my $directory	=	shift;
    print "Install::createDir    directory not defined\n" and return if not defined $directory;
    print "directory is a file: $directory\n" if -f $directory;
    return if -d $directory;
    
    print `mkdir -p $directory`;
    print "Can't create directory: $directory\n" if not -d $directory;
}

sub getArch {    
	my $self		=	shift;
	
	my $arch 	= 	"linux";
	my $command = "uname -a";
    my $output = `$command`;
	
    #### Linux ip-10-126-30-178 2.6.32-305-ec2 #9-Ubuntu SMP Thu Apr 15 08:05:38 UTC 2010 x86_64 GNU/Linux
    $arch	=	 "ubuntu" if $output =~ /ubuntu/i;
    #### Linux ip-10-127-158-202 2.6.21.7-2.fc8xen #1 SMP Fri Feb 15 12:34:28 EST 2008 x86_64 x86_64 x86_64 GNU/Linux
    $arch	=	 "centos" if $output =~ /fc\d+/;
    $arch	=	 "centos" if $output =~ /\.el\d+\./;
	$arch	=	 "debian" if $output =~ /debian/i;
	$arch	=	 "freebsd" if $output =~ /freebsd/i;
	$arch	=	 "osx" if $output =~ /darwin/i;

    print "arch:  $arch\n";
	
	return $arch;
}


sub incrementFile {
	my $self		=	shift;
	my $file		=	shift;

    $file .= ".1";	
    while ( -f $file ) {
    	my ($stub, $index) = $file =~ /^(.+?)\.(\d+)$/;
    	$index++;
    	$file = $stub . "." . $index;
    }

    return $file;    
}

sub backupFile {
	my $self			=	shift;
	my $originalfile	=	shift;
	my $backupfile		=	shift;
	my $force			=	shift; 

	#### SANITY CHECK
    print "originalfile not defined" and exit if not defined $originalfile;
    print "backupfile not defined" and exit if not defined $backupfile;
    print "Skipping backup as originalfile not present; $originalfile\n" and return if not -f $originalfile;
	print "Skipping backup as backupfile already exists: $backupfile\n" and return if -f $backupfile and not defined $force;

	#### CREATE BACKUP DIR
    my ($backupdir) = $backupfile =~ /^(.+?)\/[^\/]+$/;
    if ( not -d $backupdir ) {
    	my $command = "mkdir -p $backupdir";
		$self->runCommands([$command]);
    	print "Can't create backupdir: $backupdir\n" if not -d $backupdir;
    }

	#### COPY FILE
    my $command = "cp $originalfile $backupfile";
	$self->runCommands([$command]);
}


sub replaceFile {
	my $self			=	shift;
	my $originalfile	=	shift;
	my $replacementfile	=	shift;
	my $force			=	shift; 

    $self->backupFile($originalfile, "$originalfile.bkp", $force);

	#### SANITY CHECK
    print "Install::replaceFile    originalfile not defined" and exit if not defined $originalfile;
    print "Install::replaceFile    replacementfile not defined" and exit if not defined $replacementfile;
	print "Install::replaceFile    Can't find replacementfile: $replacementfile\n" and return if not -f $replacementfile;
    print "Install::replaceFile    Skipping as originalfile already exists: $originalfile\n" and return if -f $originalfile and not defined $force;

    my ($originaldir) = $originalfile =~ /^(.+?)\/[^\/]+$/;
    print "Install::replaceFile    Creating originaldir: $originaldir\n";
    if ( not -d $originaldir ) {
    	my $command = "mkdir -p $originaldir";
    	$self->runCommands([$command]);
    	print "Can't create originaldir: $originaldir\n" if not -d $originaldir;
    }
    
	#### COPY FILE
    my $command = "cp $replacementfile $originalfile ";
	$self->runCommands([$command]);
}



################################################################################
##################			HOUSEKEEPING SUBROUTINES			################
################################################################################

=head2

    SUBROUTINE		AUTOLOAD

    PURPOSE
    
    	AUTOMATICALLY DO 'set_' OR 'get_' FUNCTIONS IF THE
    	
    	SUBROUTINES ARE NOT DEFINED.

=cut

sub AUTOLOAD {
    my ($self, $newvalue) = @_;
    my ($operation, $attribute) = ($AUTOLOAD =~ /(get|set)(_\w+)$/);

    # Is this a legal method name?
    unless ( defined $operation && $operation && defined $attribute && $attribute ) {
        print "Method name $AUTOLOAD is not in the recognized form (get|set)_attribute\n" and exit;
    }
    
    unless( exists $self->{$attribute} )
    {
    	#if ( not defined $operation )
    	#{
            #die "No such attribute '$attribute' exists in the class ", ref($self);
    		#return;
    	#}
    }

    # Turn off strict references to enable "magic" AUTOLOAD speedup
    no strict 'refs';

    # AUTOLOAD accessors
    if($operation eq 'get') {
        # define subroutine
        *{$AUTOLOAD} = sub { shift->{$attribute} };

    # AUTOLOAD mutators
    }elsif($operation eq 'set') {
        # define subroutine4
    	
        *{$AUTOLOAD} = sub { shift->{$attribute} = shift; };

        # set the new attribute value
        $self->{$attribute} = $newvalue;
    }

    # Turn strict references back on
    use strict 'refs';

    # return the attribute value
    return $self->{$attribute};
}

=head 2

    SUBROUTINE		DESTROY
    
    PURPOSE
    
    	When an object is no longer being used, this will be automatically called
    	
    	and will adjust the count of existing objects

=cut
sub DESTROY {
    my($self) = @_;
}




1;
