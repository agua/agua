package Agua::Common::Cloud;
use Moose::Role;
use Moose::Util::TypeConstraints;

=head2

	PACKAGE		Agua::Common::Cloud
	
	PURPOSE
	
		ADMIN METHODS FOR Agua::Common
	
=cut

use Data::Dumper;

=head2

    SUBROUTINE		getCloudHeadings
    
    PURPOSE

		RETURN A LIST OF CLOUD PANES
		
=cut

sub getCloudHeadings {
	my $self		=	shift;

	##### VALIDATE    
	#my $username = $self->username();
	#$self->logError("User $username not validated") and return unless $self->validate($username);

	##### CHECK REQUESTOR
	#my $requestor = $self->requestor();
	#print qq{ error: 'Agua::Common::Cloud::getHeadings    Access denied to requestor: $requestor' } if defined $requestor;
	
	my $headings = {
		leftPane => ["Settings", "Clusters"],
		middlePane => ["Ami", "Aws"],
		rightPane => ["Hub"]
	};
	$self->logDebug("headings", $headings);
	
    return $headings;
}




1;