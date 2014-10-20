package Agua::Web::Https;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Method::Signatures;

use FindBin qw($Bin);

#### CREATE CA-AUTHENTICATED HTTPS CERTIFICATE
method installHttps {
=head2

	SUBROUTINE 		generateCACert
	
	PURPOSE
	
		1. CREATE PRIVATE KEY
		
		2. USE PRIVATE KEY TO GENERATE AUTHENTICATED CERTIFICATE
		
	NOTES
	
		1. GET DOMAIN NAME
		
		2. CREATE CONFIG FILE
		
		3. GENERATE CERTIFICATE REQUEST
		
			openssl req
		
		4. GENERATE PUBLIC CERTIFICATE

			openssl x509 -req

=cut

	#### SET FILES
	my $installdir		=	$self->conf()->getKey("agua", "INSTALLDIR");
	my $ssldir			=	"$installdir/conf/.https";
	$self->logDebug("ssldir", $ssldir);

	my $pipefile		=	"$ssldir/intermediary.pem";
	my $CA_certfile		=	"$ssldir/CA-cert.pem";
	my $configfile		=	"$ssldir/config.txt";
	my $privatekey		=	"$ssldir/id_rsa";

	#### CREATE ssldir
	`mkdir -p $ssldir` if not -d $ssldir;
	$self->logDebug("Can't create ssldir", $ssldir) if not -d $ssldir;
	
	#### 1. CREATE A PRIVATE KEY
	my $remove = "rm -fr $privatekey*";
	$self->logDebug("remove", $remove);
	`$remove`;
	my $command = qq{cd $ssldir; ssh-keygen -t rsa -f $privatekey -q -N ''};
	$self->logDebug("command", $command);
	print `$command`;	

	#### 2. GET DOMAIN NAME
	my $domainname = $self->getDomainName();
	$self->logDebug("domainname", $domainname);

	my $distinguished_name 	= 	"agua_" . $domainname . "_DN";

	#### 4. CREATE CONFIG FILE
	open(OUT, ">$configfile") or die "Can't open configfile: $configfile\n"; 	
	print OUT qq{# SSL server cert/key parms
# Cert extensions
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
basicConstraints        = CA:false
nsCertType              = server
# openssl req
[req]
default_bits            = 1024
prompt                  = no
distinguished_name      = $distinguished_name
# DN fields for SSL Server cert
[$distinguished_name]
C                       = US
ST                      = Maryland
O                       = UMCP/OIT/TSS/EIS
CN                      = $domainname
emailAddress            = trash\@trash.com
};
	close(OUT) or die "Can't close configfile: $configfile\n";

	#### 3. GENERATE CERTIFICATE REQUEST
	chdir($ssldir);
	my $request = qq{openssl \\
req \\
-config $configfile \\
-newkey rsa:1024 \\
-key $privatekey \\
-out $pipefile
};
	$self->logDebug("request", $request);
	`$request`;
	$self->logDebug("Can't find pipefile", $pipefile) and return if not -f $pipefile;

	#### 4. GENERATE PUBLIC CERTIFICATE
	chdir($ssldir);
	my $certify = qq{openssl \\
x509 -req \\
-extfile $configfile \\
-days 730 \\
-signkey $privatekey \\
-in $pipefile \\
-out $CA_certfile
};
	$self->logDebug("certify", $certify);
	`$certify`;
	$self->logDebug("Can't find CA_certfile", $CA_certfile) if not -f $CA_certfile;

	#### COPY PRIVATE KEY
	my $copyprivate = "cp -f $privatekey $ssldir/server.key";
	$self->logDebug("copyprivate", $copyprivate);
	`$copyprivate`;

	#### COPY CA CERTIFICATE
	my $copypublic = "cp -f $CA_certfile $ssldir/server.crt";
	$self->logDebug("copypublic", $copypublic);
	`$copypublic`;
}

method getDomainName {	
	my $domainname = $self->domainname();
	my $command		=	"facter domain";
	$self->logDebug("command", $command);
	$domainname = `$command` if not defined $domainname or $domainname eq "";
	chomp($domainname);
	$domainname		=	"localhost" if not defined $domainname or $domainname eq "";	
	
	return $domainname;
}


1;