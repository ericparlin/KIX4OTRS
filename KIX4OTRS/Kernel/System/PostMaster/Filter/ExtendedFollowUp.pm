# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::ExtendedFollowUp;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    $Self->{ConfigObject}       = $Kernel::OM->Get('Kernel::Config');
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{TicketObject}       = $Kernel::OM->Get('Kernel::System::Ticket');

    # get our config
    $Self->{Config} = $Self->{ConfigObject}->Get('ExtendedFollowUp');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # no config --> no mapping
    return if ( !$Self->{Config} || ref( $Self->{Config} ) ne 'HASH' );
    return if ( !$Self->{Config}->{Identifier} || ref( $Self->{Config}->{Identifier} ) ne 'HASH' );
    return
        if ( !$Self->{Config}->{SenderEmail} || ref( $Self->{Config}->{SenderEmail} ) ne 'HASH' );
    return
        if (
        !$Self->{Config}->{ExternalReference}
        || ref( $Self->{Config}->{ExternalReference} ) ne 'HASH'
        );
    return
        if (
        !$Self->{Config}->{DynamicFieldMapping}
        || ref( $Self->{Config}->{DynamicFieldMapping} ) ne 'HASH'
        );

    my %ExistingTicket;
    if ( $Param{TicketID} ) {
        %ExistingTicket = $Self->{TicketObject}->TicketGet( TicketID => $Param{TicketID} )
    }

    my %FilterKeys = %{ $Self->{Config}->{Identifier} };

    foreach my $FilterKey ( sort keys %FilterKeys ) {

        # next if not all config values for the key are set
        next
            if (
            !$Self->{Config}->{SenderEmail}->{ $FilterKeys{$FilterKey} }
            ||
            !$Self->{Config}->{ExternalReference}->{ $FilterKeys{$FilterKey} } ||
            !$Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{$FilterKey} }
            );

        # next if configured dynamic field does not exist
        my $TicketDynamicFields = $Self->{DynamicFieldObject}->DynamicFieldList(
            ObjectType => 'Ticket',
            ResultType => 'HASH',
        );
        my %DynamicFieldHash = reverse %{$TicketDynamicFields};
        next
            if (
            !defined(
                $DynamicFieldHash{
                    $Self->{Config}->{DynamicFieldMapping}
                        ->{ $FilterKeys{$FilterKey} }
                    }
            )
            );

        # next if in the existing ticket the dynamic field is not empty
        next
            if (
            %ExistingTicket
            && ref %ExistingTicket eq 'HASH'
            && $ExistingTicket{
                'DynamicField-'
                    . $Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{$FilterKey} }
            }
            );

        # sender email doesnt match
        next
            if (
            $Param{GetParam}->{From} !~
            /$Self->{Config}->{SenderEmail}->{$FilterKeys{$FilterKey}}/
            );

        my $ReferenceNumber = '';
        if (
            $Param{GetParam}->{Subject} =~
            /$Self->{Config}->{ExternalReference}->{$FilterKeys{$FilterKey}}/
            )
        {
            $ReferenceNumber = $1;
        }

        if ($ReferenceNumber) {

            # write DynamicField
            $Param{GetParam}->{
                'X-OTRS-FollowUp-DynamicField-'
                    . $Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{$FilterKey} }
                }
                =
                $ReferenceNumber;

            # if no ticket was found by followup search on by external reference_number

            if ( !$Param{TicketID} ) {

                my @TicketIDs = $Self->{TicketObject}->TicketSearch(
                    Result => 'ARRAY',
                    'DynamicField_'
                        . $Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{$FilterKey} } => {
                        Like => $ReferenceNumber,
                        },
                    UserID  => 1,
                    OrderBy => [ $Self->{Config}->{SortByAgeOrder} ],
                    SortBy  => ['Age'],
                );

                if ( scalar(@TicketIDs) > 0 ) {
                    ## TODO
                    my $TicketNumber = '';

                    # if ticket statetype isn't relevat
                    if ( $Self->{Config}->{AllTicketStateTypesIncluded} ) {
                        $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
                            TicketID => $TicketIDs[0],
                            UserID   => 1,
                        );
                    }

                    # if ticket statetape should by pending or open
                    else {
                        for my $TicketID (@TicketIDs) {
                            my %Ticket = $Self->{TicketObject}->TicketGet(
                                TicketID => $TicketID,
                                UserID   => 1,
                            );

                            if ( $Ticket{StateType} =~ /^(pending|new|open)/ ) {
                                $TicketNumber = $Ticket{TicketNumber};
                                last;
                            }
                        }

# if open/pending tickets should be take and no one was found the first closed ticket will be choose
                        if ( !$TicketNumber ) {
                            $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
                                TicketID => $TicketIDs[0],
                                UserID   => 1,
                            );
                        }
                    }

                    if ($TicketNumber) {
                        $Param{GetParam}->{'Subject'} = $Self->{TicketObject}->TicketSubjectBuild(
                            TicketNumber => $TicketNumber,
                            Subject      => $Param{GetParam}->{'Subject'},
                            Type         => 'New',
                            NoCleanup    => 1,
                        );
                    }
                }
            }
        }
    }

    #...done...
    return 1;

}

1;
