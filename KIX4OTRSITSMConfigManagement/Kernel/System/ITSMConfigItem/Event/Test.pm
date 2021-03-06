# --
# Kernel/System/ITSMConfigItem/Event/Test.pm - test event module
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Event::Test;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    $Self->{LogObject}   = $Kernel::OM->Get('Kernel::System::Log');

    my @keyarr = keys(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my %Error = ();

    #check required params...
    foreach (qw(Event UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "ITSMConfigItem-Event-Test: Need $_!"
            );
            return;
        }
    }

    my @ParamKeys = keys(%Param);

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => "ITSMConfigItem-Event-Test: Event ($Param{Event}) "
            . "occured - keys: @ParamKeys."
    );

    #
    # THIS IS THE PART WHERE THE ACTUAL WORK IS DONE
    # ...check attributes, links and all this stuff...
    #

    #if this is a PreEvent, it's possible to change or add params in the calling module...
    #content of %ReturnParams will update %Param...
    #my %ReturnParams = ();
    #$ReturnParams{KEY} = NEWValue;
    #return \%ReturnParams;
    #...of course, the calling module needs to know about this

    #if some plausi check fails, set the error code an the corresponding message for the user...
    $Error{Error}   = 42;
    $Error{Message} = "Dude, this will never work - because it's a permanent message!";

#   ...of course, the calling module need to know about this. If so, it will be shown in the frontend...

    return \%Error;

}

1;
