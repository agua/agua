package Agua::CLI::Util;
use Moose::Role;
use Method::Signatures::Simple;

=head2

ROLE        Agua::CLI::Util

PURPOSE

	1. PROVIDE COMMON UTILITY METHODS FOR Agua::CLI CLASSES

=cut

#Boolean

# Ints

# Strings

# Objects


method getLoader {
	$self->logDebug("self->logfile", $self->logfile());
	
	return Agua::Package->new({
		username	=>	$self->username(),
		database	=>	$self->database(),
		logfile		=>	$self->logfile(),
		log			=>	$self->log(),
		printlog	=>	$self->printlog(),
		conf		=>	$self->conf(),
		db	        =>	$self->db()
	});
}

method setUsername {
	my $whoami    =   `whoami`;
	$whoami       =~  s/\s+$//;
	$self->logDebug("whoami", $whoami);

	#### RETURN ACCOUNT NAME IF NOT ROOT
	if ( $whoami ne "root" ) {
		$self->username($whoami);
		return $whoami;
	}
	
	#### OTHERWISE, SET USERNAME IF PROVIDED
	my $username    =   $self->username();
	$self->logDebug("username", $username);
	if ( defined $username and $username ne "" ) {
		$self->username($username);
		return $username;
	}
	else {
		$self->username($whoami);
		return $whoami;
	}
}


no Moose::Role;

1;