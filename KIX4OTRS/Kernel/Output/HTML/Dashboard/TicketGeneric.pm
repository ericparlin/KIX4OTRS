# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# KIX4OTRS-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::TicketGeneric;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed parameters
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $RemoveFilters = $ParamObject->GetParam( Param => 'RemoveFilters' )
        || $Param{RemoveFilters}
        || 0;

    # get sorting params
    for my $Item (qw(SortBy OrderBy)) {
        $Self->{$Item} = $ParamObject->GetParam( Param => $Item ) || $Param{$Item};
    }

    # set filter settings
    for my $Item (qw(ColumnFilter GetColumnFilter GetColumnFilterSelect)) {
        $Self->{$Item} = $Param{$Item};
    }

    # save column filters
    $Self->{PrefKeyColumnFilters}         = 'UserDashboardTicketGenericColumnFilters' . $Self->{Name};
    $Self->{PrefKeyColumnFiltersRealKeys} = 'UserDashboardTicketGenericColumnFiltersRealKeys' . $Self->{Name};

    # get needed objects
    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

    if ($RemoveFilters) {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Self->{PrefKeyColumnFilters},
            Value  => '',
        );
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Self->{PrefKeyColumnFiltersRealKeys},
            Value  => '',
        );
    }

    # just in case new filter values arrive
    elsif (
        IsHashRefWithData( $Self->{GetColumnFilter} )
        && IsHashRefWithData( $Self->{GetColumnFilterSelect} )
        && IsHashRefWithData( $Self->{ColumnFilter} )
        )
    {

        if ( !$ConfigObject->Get('DemoSystem') ) {

            # check if the user has filter preferences for this widget
            my %Preferences = $UserObject->GetPreferences(
                UserID => $Self->{UserID},
            );
            my $ColumnPrefValues;
            if ( $Preferences{ $Self->{PrefKeyColumnFilters} } ) {
                $ColumnPrefValues = $JSONObject->Decode(
                    Data => $Preferences{ $Self->{PrefKeyColumnFilters} },
                );
            }

            PREFVALUES:
            for my $Column ( sort keys %{ $Self->{GetColumnFilterSelect} } ) {
                if ( $Self->{GetColumnFilterSelect}->{$Column} eq 'DeleteFilter' ) {
                    delete $ColumnPrefValues->{$Column};
                    next PREFVALUES;
                }
                $ColumnPrefValues->{$Column} = $Self->{GetColumnFilterSelect}->{$Column};
            }

            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Self->{PrefKeyColumnFilters},
                Value  => $JSONObject->Encode( Data => $ColumnPrefValues ),
            );

            # save real key's name
            my $ColumnPrefRealKeysValues;
            if ( $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} } ) {
                $ColumnPrefRealKeysValues = $JSONObject->Decode(
                    Data => $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} },
                );
            }
            REALKEYVALUES:
            for my $Column ( sort keys %{ $Self->{ColumnFilter} } ) {
                next REALKEYVALUES if !$Column;

                my $DeleteFilter = 0;
                if ( IsArrayRefWithData( $Self->{ColumnFilter}->{$Column} ) ) {
                    if ( grep { $_ eq 'DeleteFilter' } @{ $Self->{ColumnFilter}->{$Column} } ) {
                        $DeleteFilter = 1;
                    }
                }
                elsif ( IsHashRefWithData( $Self->{ColumnFilter}->{$Column} ) ) {

                    if (
                        grep { $Self->{ColumnFilter}->{$Column}->{$_} eq 'DeleteFilter' }
                        keys %{ $Self->{ColumnFilter}->{$Column} }
                        )
                    {
                        $DeleteFilter = 1;
                    }
                }

                if ($DeleteFilter) {
                    delete $ColumnPrefRealKeysValues->{$Column};
                    delete $Self->{ColumnFilter}->{$Column};
                    next REALKEYVALUES;
                }
                $ColumnPrefRealKeysValues->{$Column} = $Self->{ColumnFilter}->{$Column};
            }
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Self->{PrefKeyColumnFiltersRealKeys},
                Value  => $JSONObject->Encode( Data => $ColumnPrefRealKeysValues ),
            );

        }
    }

    # check if the user has filter preferences for this widget
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    # get column names from Preferences
    my $PreferencesColumnFilters;
    if ( $Preferences{ $Self->{PrefKeyColumnFilters} } ) {
        $PreferencesColumnFilters = $JSONObject->Decode(
            Data => $Preferences{ $Self->{PrefKeyColumnFilters} },
        );
    }

    if ($PreferencesColumnFilters) {
        $Self->{GetColumnFilterSelect} = $PreferencesColumnFilters;
        my @ColumnFilters = keys %{$PreferencesColumnFilters};    ## no critic
        for my $Field (@ColumnFilters) {
            $Self->{GetColumnFilter}->{ $Field . $Self->{Name} } = $PreferencesColumnFilters->{$Field};
        }
    }

    # get column real names from Preferences
    my $PreferencesColumnFiltersRealKeys;
    if ( $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} } ) {
        $PreferencesColumnFiltersRealKeys = $JSONObject->Decode(
            Data => $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} },
        );
    }

    if ($PreferencesColumnFiltersRealKeys) {
        my @ColumnFiltersReal = keys %{$PreferencesColumnFiltersRealKeys};    ## no critic
        for my $Field (@ColumnFiltersReal) {
            $Self->{ColumnFilter}->{$Field} = $PreferencesColumnFiltersRealKeys->{$Field};
        }
    }

    # get current filter
    my $Name = $ParamObject->GetParam( Param => 'Name' ) || '';
    my $PreferencesKey = 'UserDashboardTicketGenericFilter' . $Self->{Name};
    if ( $Self->{Name} eq $Name ) {
        $Self->{Filter} = $ParamObject->GetParam( Param => 'Filter' ) || '';
    }

    # remember filter
    if ( $Self->{Filter} ) {

        # update session
        $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => $PreferencesKey,
            Value     => $Self->{Filter},
        );

        # update preferences
        if ( !$ConfigObject->Get('DemoSystem') ) {
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $PreferencesKey,
                Value  => $Self->{Filter},
            );
        }
    }
    else {
        $Self->{Filter} = $Self->{$PreferencesKey} || $Self->{Config}->{Filter} || 'All';
    }

    $Self->{PrefKeyShown}   = 'UserDashboardPref' . $Self->{Name} . '-Shown';
    $Self->{PrefKeyColumns} = 'UserDashboardPref' . $Self->{Name} . '-Columns';
    $Self->{PageShown}      = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{ $Self->{PrefKeyShown} }
        || $Self->{Config}->{Limit};
    $Self->{StartHit} = int( $ParamObject->GetParam( Param => 'StartHit' ) || 1 );

    # KIX4OTRS-capeIT
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{PrefKeySearchTemplate} = 'UserDashboardPref' . $Self->{Name};
    $Self->{SearchTemplateName} = $LayoutObject->{ $Self->{PrefKeySearchTemplate} } || '';

    for my $Item ( keys %{ $Kernel::OM->Get('Kernel::Output::HTML::Layout') } ) {
        next if $Item !~ m/^UserDashboard(.*)Template(.*)/i;
    }

    # define filterable columns
    $Self->{ValidFilterableColumns} = {
        'Owner'          => 1,
        'Responsible'    => 1,
        'CustomerID'     => 1,
        'CustomerUserID' => 1,
        'State'          => 1,
        'Queue'          => 1,
        'Priority'       => 1,
        'Type'           => 1,
        'Lock'           => 1,
        'Service'        => 1,
        'SLA'            => 1,
    };

    # hash with all valid sortable columns (taken from TicketSearch)
    # SortBy  => 'Age',   # Created|Owner|Responsible|CustomerID|State|TicketNumber|Queue
    # |Priority|Type|Lock|Title|Service|SLA|Changed|PendingTime|EscalationTime
    # | EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    $Self->{ValidSortableColumns} = {
        'Age'                    => 1,
        'Created'                => 1,
        'Owner'                  => 1,
        'Responsible'            => 1,
        'CustomerID'             => 1,
        'State'                  => 1,
        'TicketNumber'           => 1,
        'Queue'                  => 1,
        'Priority'               => 1,
        'Type'                   => 1,
        'Lock'                   => 1,
        'Title'                  => 1,
        'Service'                => 1,
        'Changed'                => 1,
        'SLA'                    => 1,
        'PendingTime'            => 1,
        'EscalationTime'         => 1,
        'EscalationUpdateTime'   => 1,
        'EscalationResponseTime' => 1,
        'EscalationSolutionTime' => 1,
    };

    # remove CustomerID if Customer Information Center
    if ( $Self->{Action} eq 'AgentCustomerInformationCenter' ) {
        delete $Self->{ColumnFilter}->{CustomerID};
        delete $Self->{GetColumnFilter}->{CustomerID};
        delete $Self->{GetColumnFilterSelect}->{CustomerID};
        delete $Self->{ValidFilterableColumns}->{CustomerID};
        delete $Self->{ValidSortableColumns}->{CustomerID};
    }

    $Self->{UseTicketService} = $ConfigObject->Get('Ticket::Service') || 0;

    if ( $Self->{Config}->{IsProcessWidget} ) {

        # get process management configuration
        $Self->{ProcessManagementProcessID}
            = $Kernel::OM->Get('Kernel::Config')->Get('Process::DynamicFieldProcessManagementProcessID');
        $Self->{ProcessManagementActivityID}
            = $Kernel::OM->Get('Kernel::Config')->Get('Process::DynamicFieldProcessManagementActivityID');

        # get the list of processes in the system
        my $ProcessListHash = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process')->ProcessList(
            ProcessState => [ 'Active', 'FadeAway', 'Inactive' ],
            Interface    => 'all',
            Silent       => 1,
        );

        # use only the process EntityIDs
        @{ $Self->{ProcessList} } = sort keys %{$ProcessListHash};
    }

    # load and save SortBy and OrderBy
    if ( !$Self->{OrderBy} ) {
        my %SearchParams = $Self->_SearchParamsGet(%Param);
        $Self->{OrderBy}
            = $Preferences{ 'UserDashboardPref' . $Self->{Name} . '-OrderBy' }
            || $SearchParams{TicketSearch}->{OrderBy}
            || "Down";
    }
    else {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserDashboardPref' . $Self->{Name} . '-OrderBy',
            Value  => $Self->{OrderBy},
        );
    }

    if ( !$Self->{SortBy} ) {
        my %SearchParams = $Self->_SearchParamsGet(%Param);
        $Self->{SortBy}
            = $Preferences{ 'UserDashboardPref' . $Self->{Name} . '-SortBy' }
            || $Self->{Config}->{DefaultSort}
            || $SearchParams{TicketSearch}->{SortBy}
            || "TicketNumber";
    }
    else {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserDashboardPref' . $Self->{Name} . '-SortBy',
            Value  => $Self->{SortBy},
        );
    }

    # EO KIX4OTRS-capeIT

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    # configure columns
    my @ColumnsEnabled;
    my @ColumnsAvailable;
    my @ColumnsAvailableNotEnabled;

    # check for default settings
    if (
        $Self->{Config}->{DefaultColumns}
        && IsHashRefWithData( $Self->{Config}->{DefaultColumns} )
        )
    {
        @ColumnsAvailable = grep { $Self->{Config}->{DefaultColumns}->{$_} }
            keys %{ $Self->{Config}->{DefaultColumns} };
        @ColumnsEnabled = grep { $Self->{Config}->{DefaultColumns}->{$_} eq '2' }
            sort { $Self->_DefaultColumnSort() } keys %{ $Self->{Config}->{DefaultColumns} };
    }

    # check if the user has filter preferences for this widget
    my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $Self->{UserID},
    );

    # get JSON object
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # if preference settings are available, take them
    # KIX4OTRS-capeIT
    if ( defined $Preferences{ $Self->{PrefKeyColumns} }
        && $Preferences{ $Self->{PrefKeyColumns} } )
    {

        # fallback to use old configuration
        # my $ColumnsEnabled = $JSONObject->Decode(
        #     Data => $LayoutObject->{ $Self->{PrefKeyColumns} },
        # );

        my $ColumnsEnabled;
        my $ColumnPreferences = $Preferences{ $Self->{PrefKeyColumns} };
        my @OldConfigArray = split( /;/, $ColumnPreferences );

        if ( $ColumnPreferences =~ /^\{\"Columns\".*?\}$/ ) {

            # get column names from Preferences
            $ColumnsEnabled = $JSONObject->Decode(
                Data => $Preferences{ $Self->{PrefKeyColumns} },
            );
        }
        elsif ( scalar @OldConfigArray ) {

            # set default values
            $ColumnsEnabled->{Columns}->{TicketNumber} = 1;
            $ColumnsEnabled->{Columns}->{Title}        = 1;
            $ColumnsEnabled->{Columns}->{Age}          = 1;

            push( @{ $ColumnsEnabled->{Order} }, ( 'TicketNumber', 'Title', 'Age' ) );

            # get already set values
            for my $Column (@OldConfigArray) {
                $ColumnsEnabled->{Columns}->{$Column} = 1;
                push( @{ $ColumnsEnabled->{Order} }, $Column );
            }
        }

        # EO KIX4OTRS-capeIT

        @ColumnsEnabled = grep { $ColumnsEnabled->{Columns}->{$_} == 1 }
            keys %{ $ColumnsEnabled->{Columns} };

        if ( $ColumnsEnabled->{Order} && @{ $ColumnsEnabled->{Order} } ) {
            @ColumnsEnabled = @{ $ColumnsEnabled->{Order} };
        }

        # remove duplicate columns
        my %UniqueColumns;
        my @ColumnsEnabledAux;

        for my $Column (@ColumnsEnabled) {
            if ( !$UniqueColumns{$Column} ) {
                push @ColumnsEnabledAux, $Column;
            }
            $UniqueColumns{$Column} = 1;
        }

        # set filtered column list
        @ColumnsEnabled = @ColumnsEnabledAux;
    }

    my %Columns;
    for my $ColumnName ( sort { $a cmp $b } @ColumnsAvailable ) {
        $Columns{Columns}->{$ColumnName} = ( grep { $ColumnName eq $_ } @ColumnsEnabled ) ? 1 : 0;
        if ( !grep { $_ eq $ColumnName } @ColumnsEnabled ) {
            push @ColumnsAvailableNotEnabled, $ColumnName;
        }
    }

    # KIX4OTRS-capeIT
    # sort available columns depending on selected language
    my %ColumnsAvailableTranslated;
    for my $Column (@ColumnsAvailableNotEnabled) {
        if ( $Column =~ m/^DynamicField_(.*?)$/ ) {
            my $DynamicField
                = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet( Name => $1 );
            $ColumnsAvailableTranslated{$Column}
                = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}
                ->Translate( $DynamicField->{Label} );
        }
        else {
            $ColumnsAvailableTranslated{$Column}
                = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}
                ->Translate($Column);
        }
    }

    @ColumnsAvailableNotEnabled
        = sort {
        ( $ColumnsAvailableTranslated{$a} || '' ) cmp( $ColumnsAvailableTranslated{$b} || '' )
        }
        keys %ColumnsAvailableTranslated;

    # EO KIX4OTRS-capeIT

    # remove CustomerID if Customer Information Center
    if ( $Self->{Action} eq 'AgentCustomerInformationCenter' ) {
        delete $Columns{Columns}->{CustomerID};
        @ColumnsEnabled             = grep { $_ ne 'CustomerID' } @ColumnsEnabled;
        @ColumnsAvailableNotEnabled = grep { $_ ne 'CustomerID' } @ColumnsAvailableNotEnabled;
    }

    # KIX4OTRS-capeIT
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my %User       = $UserObject->GetUserData(
        UserID => $Self->{UserID},
    );

    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');

    my %SearchProfileParams;
    if ( $Self->{Name} =~ /SearchTemplate/ ) {

        my %SearchProfiles = $SearchProfileObject->SearchProfileList(
            Base      => 'TicketSearch',
            UserLogin => $User{UserLogin},
        );

        # delete empty profile and last search
        $SearchProfiles{''} = '-';
        delete $SearchProfiles{'last-search'};

        %SearchProfileParams =
            (
            Desc  => 'Search Profile',
            Name  => $Self->{PrefKeySearchTemplate},
            Block => 'Option',

            Data => {
                %SearchProfiles,
            },
            SelectedID => $User{ $Self->{PrefKeySearchTemplate} } || '',
            Translation => 0,
            );
    }

    # EO KIX4OTRS-capeIT

    my @Params = (
        {
            Desc  => Translatable('Shown Tickets'),
            Name  => $Self->{PrefKeyShown},
            Block => 'Option',
            Data  => {
                5  => ' 5',
                10 => '10',
                15 => '15',
                20 => '20',
                25 => '25',
            },
            SelectedID  => $Self->{PageShown},
            Translation => 0,
        },
        {
            Desc             => Translatable('Shown Columns'),
            Name             => $Self->{PrefKeyColumns},
            Block            => 'AllocationList',
            Columns          => $JSONObject->Encode( Data => \%Columns ),
            ColumnsEnabled   => $JSONObject->Encode( Data => \@ColumnsEnabled ),
            ColumnsAvailable => $JSONObject->Encode( Data => \@ColumnsAvailableNotEnabled ),
            Translation      => 1,
        },
    );

    # KIX4OTRS-capeIT
    if ( $Self->{Name} =~ /SearchTemplate/ ) {
        push( @Params, \%SearchProfileParams );
    }

    # EO KIX4OTRS-capeIT

    return @Params;
}

sub Config {
    my ( $Self, %Param ) = @_;

    # check if frontend module of link is used
    if ( $Self->{Config}->{Link} && $Self->{Config}->{Link} =~ /Action=(.+?)([&;].+?|)$/ ) {
        my $Action = $1;
        if ( !$Kernel::OM->Get('Kernel::Config')->Get('Frontend::Module')->{$Action} ) {
            $Self->{Config}->{Link} = '';
        }
    }

    return (
        %{ $Self->{Config} },

        # Don't cache this globally as it contains JS that is not inside of the HTML.
        CacheTTL => undef,
        CacheKey => undef,
    );
}

sub FilterContent {
    my ( $Self, %Param ) = @_;

    return if !$Param{FilterColumn};

    my $TicketIDs;
    my $HeaderColumn = $Param{FilterColumn};
    my @OriginalViewableTickets;

    if (
        $Kernel::OM->Get('Kernel::Config')->Get('OnlyValuesOnTicket')
        || $HeaderColumn eq 'CustomerID'
        || $HeaderColumn eq 'CustomerUserID'
        )
    {
        my %SearchParams        = $Self->_SearchParamsGet(%Param);
        my %TicketSearch        = %{ $SearchParams{TicketSearch} };
        my %TicketSearchSummary = %{ $SearchParams{TicketSearchSummary} };

        # add process management search terms
        if ( $Self->{Config}->{IsProcessWidget} ) {
            $TicketSearch{ 'DynamicField_' . $Self->{ProcessManagementProcessID} } = {
                Like => $Self->{ProcessList},
            };
        }

        if (
            !$Self->{Config}->{IsProcessWidget}
            || IsArrayRefWithData( $Self->{ProcessList} )
            )
        {
            @OriginalViewableTickets = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                %TicketSearch,
                %{ $TicketSearchSummary{ $Self->{Filter} } },
                Result => 'ARRAY',
            );
        }
    }

    if ( $HeaderColumn =~ m/^DynamicField_/ && !defined $Self->{DynamicField} ) {

        # get the dynamic fields for this screen
        $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
            Valid      => 0,
            ObjectType => ['Ticket'],
        );
    }

    # get column values for to build the filters later
    my $ColumnValues = $Self->_GetColumnValues(
        OriginalTicketIDs => \@OriginalViewableTickets,
        HeaderColumn      => $HeaderColumn,
    );

    # make sure that even a value of 0 is passed as a Selected value, e.g. Unchecked value of a
    # check-box dynamic field.
    my $SelectedValue = defined $Self->{GetColumnFilter}->{ $HeaderColumn . $Self->{Name} }
        ? $Self->{GetColumnFilter}->{ $HeaderColumn . $Self->{Name} }
        : '';

    my $LabelColumn = $HeaderColumn;
    if ( $LabelColumn =~ m{ \A DynamicField_ }xms ) {

        my $DynamicFieldConfig;
        $LabelColumn =~ s{\A DynamicField_ }{}xms;

        DYNAMICFIELD:
        for my $DFConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
            next DYNAMICFIELD if $DFConfig->{Name} ne $LabelColumn;

            $DynamicFieldConfig = $DFConfig;
            last DYNAMICFIELD;
        }
        if ( IsHashRefWithData($DynamicFieldConfig) ) {
            $LabelColumn = $DynamicFieldConfig->{Label};
        }
    }

    # variable to save the filter's HTML code
    my $ColumnFilterJSON = $Self->_ColumnFilterJSON(
        ColumnName    => $HeaderColumn,
        Label         => $LabelColumn,
        ColumnValues  => $ColumnValues->{$HeaderColumn},
        SelectedValue => $SelectedValue,
        DashboardName => $Self->{Name},
    );

    return $ColumnFilterJSON;

}

sub Run {
    my ( $Self, %Param ) = @_;

    my %SearchParams        = $Self->_SearchParamsGet(%Param);
    my @Columns             = @{ $SearchParams{Columns} };
    my %TicketSearch        = %{ $SearchParams{TicketSearch} };
    my %TicketSearchSummary = %{ $SearchParams{TicketSearchSummary} };

    my $CacheKey = join '-', $Self->{Name},
        $Self->{Action},
        $Self->{PageShown},
        $Self->{StartHit},
        $Self->{UserID};
    my $CacheColumns = join(
        ',',
        map {
            $_ . '=>' . $Self->{GetColumnFilterSelect}->{$_}
            }
            sort keys %{ $Self->{GetColumnFilterSelect} }
    );
    $CacheKey .= '-' . $CacheColumns if $CacheColumns;

    $CacheKey .= '-' . $Self->{SortBy}  if defined $Self->{SortBy};
    $CacheKey .= '-' . $Self->{OrderBy} if defined $Self->{OrderBy};

    # CustomerInformationCenter shows data per CustomerID
    if ( $Param{CustomerID} ) {

        # KIX4OTRS-capeIT
        $TicketSearch{CustomerID} = $Param{CustomerID};

        # EO KIX4OTRS-capeIT
        $CacheKey .= '-' . $Param{CustomerID};
    }

    # KIX4OTRS-capeIT
    elsif ( $Param{CustomerUserLogin} ) {
        $TicketSearch{CustomerUserLogin} = $Param{CustomerUserLogin};
    }

    # EO KIX4OTRS-capeIT

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # KIX4OTRS-capeIT
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my %SearchProfileData;
    if ( $Self->{SearchTemplateName} ) {
        my $SearchProfileUser;
        my $SearchProfile;

        if ( $Self->{SearchTemplateName} =~ m/^(.*?)::(.*?)$/ ) {
            $SearchProfileUser = $2;
            $SearchProfile     = $1;
        }
        else {
            my %User = $UserObject->GetUserData(
                UserID => $Self->{UserID},
            );
            $SearchProfileUser = $User{UserLogin};
            $SearchProfile     = $Self->{SearchTemplateName};
        }

        %SearchProfileData = $SearchProfileObject->SearchProfileGet(
            Base      => 'TicketSearch',
            Name      => $SearchProfile,
            UserLogin => $SearchProfileUser,
        );

        # add dynamic fields search criteria
        $Self->{DynamicField} =
            $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => ['Ticket'],
            );

        # create attibute lookup table
        my %AttributeLookup;
        for my $Attribute ( @{ $SearchProfileData{ShownAttributes} || [] } ) {
            $AttributeLookup{$Attribute} = 1;
        }

        # dynamic fields search parameters for ticket search
        my %DynamicFieldSearchParameters;

        # get backend object
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if ( ref($DynamicFieldConfig) ne 'HASH' );
            next DYNAMICFIELD if ( !%{$DynamicFieldConfig} );
            next DYNAMICFIELD
                if !$AttributeLookup{
                        'LabelSearch_DynamicField_'
                            . $DynamicFieldConfig->{Name}
                    };

            # extract the dynamic field value form the profile
            my $SearchParameter =
                $DynamicFieldBackendObject->SearchFieldParameterBuild(
                DynamicFieldConfig => $DynamicFieldConfig,
                Profile            => \%SearchProfileData,
                LayoutObject       => $LayoutObject,
                );

            # set search parameter
            if ( defined $SearchParameter ) {

                $DynamicFieldSearchParameters{
                    'DynamicField_'
                        . $DynamicFieldConfig->{Name}
                    }
                    =
                    $SearchParameter->{Parameter};
            }
        }

        # update TicketSearch
        %TicketSearch = (
            %DynamicFieldSearchParameters,
            %TicketSearch,
            Permission => $Self->{Config}->{Permission} || 'ro',
            UserID => $Self->{UserID},
        );

        # convert attributes
        if (
            $SearchProfileData{ShownAttributes}
            && ref $SearchProfileData{ShownAttributes} eq 'ARRAY'
            )
        {
            $SearchProfileData{ShownAttributes} = join ';',
                @{ $SearchProfileData{ShownAttributes} };
        }

        #########
        # needed to search for time
        # get create time settings
        if ( !$SearchProfileData{ArticleTimeSearchType} ) {

            # do nothing with time stuff
        }
        elsif ( $SearchProfileData{ArticleTimeSearchType} eq 'TimeSlot' ) {
            for (qw(Month Day)) {
                $SearchProfileData{"ArticleCreateTimeStart$_"}
                    = sprintf( "%02d", $SearchProfileData{"ArticleCreateTimeStart$_"} );
            }
            for (qw(Month Day)) {
                $SearchProfileData{"ArticleCreateTimeStop$_"}
                    = sprintf( "%02d", $SearchProfileData{"ArticleCreateTimeStop$_"} );
            }
            if (
                $SearchProfileData{ArticleCreateTimeStartDay}
                && $SearchProfileData{ArticleCreateTimeStartMonth}
                && $SearchProfileData{ArticleCreateTimeStartYear}
                )
            {
                $SearchProfileData{ArticleCreateTimeNewerDate}
                    = $SearchProfileData{ArticleCreateTimeStartYear} . '-'
                    . $SearchProfileData{ArticleCreateTimeStartMonth} . '-'
                    . $SearchProfileData{ArticleCreateTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $SearchProfileData{ArticleCreateTimeStopDay}
                && $SearchProfileData{ArticleCreateTimeStopMonth}
                && $SearchProfileData{ArticleCreateTimeStopYear}
                )
            {
                $SearchProfileData{ArticleCreateTimeOlderDate}
                    = $SearchProfileData{ArticleCreateTimeStopYear} . '-'
                    . $SearchProfileData{ArticleCreateTimeStopMonth} . '-'
                    . $SearchProfileData{ArticleCreateTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $SearchProfileData{ArticleTimeSearchType} eq 'TimePoint' ) {
            if (
                $SearchProfileData{ArticleCreateTimePoint}
                && $SearchProfileData{ArticleCreateTimePointStart}
                && $SearchProfileData{ArticleCreateTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'minute' ) {
                    $Time = $SearchProfileData{ArticleCreateTimePoint};
                }
                elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'hour' ) {
                    $Time = $SearchProfileData{ArticleCreateTimePoint} * 60;
                }
                elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'day' ) {
                    $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24;
                }
                elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'week' ) {
                    $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24 * 7;
                }
                elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'month' ) {
                    $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24 * 30;
                }
                elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'year' ) {
                    $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24 * 365;
                }
                if ( $SearchProfileData{ArticleCreateTimePointStart} eq 'Before' ) {
                    $SearchProfileData{ArticleCreateTimeOlderMinutes} = $Time;
                }
                else {
                    $SearchProfileData{ArticleCreateTimeNewerMinutes} = $Time;
                }
            }
        }

        # get create time settings
        if ( !$SearchProfileData{TimeSearchType} ) {

            # do nothing with time stuff
        }
        elsif ( $SearchProfileData{TimeSearchType} eq 'TimeSlot' ) {
            for (qw(Month Day)) {
                $SearchProfileData{"TicketCreateTimeStart$_"}
                    = sprintf( "%02d", $SearchProfileData{"TicketCreateTimeStart$_"} );
            }
            for (qw(Month Day)) {
                $SearchProfileData{"TicketCreateTimeStop$_"}
                    = sprintf( "%02d", $SearchProfileData{"TicketCreateTimeStop$_"} );
            }
            if (
                $SearchProfileData{TicketCreateTimeStartDay}
                && $SearchProfileData{TicketCreateTimeStartMonth}
                && $SearchProfileData{TicketCreateTimeStartYear}
                )
            {
                $SearchProfileData{TicketCreateTimeNewerDate}
                    = $SearchProfileData{TicketCreateTimeStartYear} . '-'
                    . $SearchProfileData{TicketCreateTimeStartMonth} . '-'
                    . $SearchProfileData{TicketCreateTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $SearchProfileData{TicketCreateTimeStopDay}
                && $SearchProfileData{TicketCreateTimeStopMonth}
                && $SearchProfileData{TicketCreateTimeStopYear}
                )
            {
                $SearchProfileData{TicketCreateTimeOlderDate}
                    = $SearchProfileData{TicketCreateTimeStopYear} . '-'
                    . $SearchProfileData{TicketCreateTimeStopMonth} . '-'
                    . $SearchProfileData{TicketCreateTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $SearchProfileData{TimeSearchType} eq 'TimePoint' ) {
            if (
                $SearchProfileData{TicketCreateTimePoint}
                && $SearchProfileData{TicketCreateTimePointStart}
                && $SearchProfileData{TicketCreateTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $SearchProfileData{TicketCreateTimePointFormat} eq 'minute' ) {
                    $Time = $SearchProfileData{TicketCreateTimePoint};
                }
                elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'hour' ) {
                    $Time = $SearchProfileData{TicketCreateTimePoint} * 60;
                }
                elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'day' ) {
                    $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24;
                }
                elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'week' ) {
                    $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24 * 7;
                }
                elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'month' ) {
                    $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24 * 30;
                }
                elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'year' ) {
                    $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24 * 365;
                }
                if ( $SearchProfileData{TicketCreateTimePointStart} eq 'Before' ) {
                    $SearchProfileData{TicketCreateTimeOlderMinutes} = $Time;
                }
                else {
                    $SearchProfileData{TicketCreateTimeNewerMinutes} = $Time;
                }
            }
        }

        # get close time settings
        if ( !$SearchProfileData{ChangeTimeSearchType} ) {

            # do nothing on time stuff
        }
        elsif ( $SearchProfileData{ChangeTimeSearchType} eq 'TimeSlot' ) {
            for (qw(Month Day)) {
                $SearchProfileData{"TicketChangeTimeStart$_"}
                    = sprintf( "%02d", $SearchProfileData{"TicketChangeTimeStart$_"} );
            }
            for (qw(Month Day)) {
                $SearchProfileData{"TicketChangeTimeStop$_"}
                    = sprintf( "%02d", $SearchProfileData{"TicketChangeTimeStop$_"} );
            }
            if (
                $SearchProfileData{TicketChangeTimeStartDay}
                && $SearchProfileData{TicketChangeTimeStartMonth}
                && $SearchProfileData{TicketChangeTimeStartYear}
                )
            {
                $SearchProfileData{TicketChangeTimeNewerDate}
                    = $SearchProfileData{TicketChangeTimeStartYear} . '-'
                    . $SearchProfileData{TicketChangeTimeStartMonth} . '-'
                    . $SearchProfileData{TicketChangeTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $SearchProfileData{TicketChangeTimeStopDay}
                && $SearchProfileData{TicketChangeTimeStopMonth}
                && $SearchProfileData{TicketChangeTimeStopYear}
                )
            {
                $SearchProfileData{TicketChangeTimeOlderDate}
                    = $SearchProfileData{TicketChangeTimeStopYear} . '-'
                    . $SearchProfileData{TicketChangeTimeStopMonth} . '-'
                    . $SearchProfileData{TicketChangeTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $SearchProfileData{ChangeTimeSearchType} eq 'TimePoint' ) {
            if (
                $SearchProfileData{TicketChangeTimePoint}
                && $SearchProfileData{TicketChangeTimePointStart}
                && $SearchProfileData{TicketChangeTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $SearchProfileData{TicketChangeTimePointFormat} eq 'minute' ) {
                    $Time = $SearchProfileData{TicketChangeTimePoint};
                }
                elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'hour' ) {
                    $Time = $SearchProfileData{TicketChangeTimePoint} * 60;
                }
                elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'day' ) {
                    $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24;
                }
                elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'week' ) {
                    $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24 * 7;
                }
                elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'month' ) {
                    $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24 * 30;
                }
                elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'year' ) {
                    $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24 * 365;
                }
                if ( $SearchProfileData{TicketChangeTimePointStart} eq 'Before' ) {
                    $SearchProfileData{TicketChangeTimeOlderMinutes} = $Time;
                }
                else {
                    $SearchProfileData{TicketChangeTimeNewerMinutes} = $Time;
                }
            }
        }

        # get close time settings
        if ( !$SearchProfileData{CloseTimeSearchType} ) {

            # do nothing on time stuff
        }
        elsif ( $SearchProfileData{CloseTimeSearchType} eq 'TimeSlot' ) {
            for (qw(Month Day)) {
                $SearchProfileData{"TicketCloseTimeStart$_"}
                    = sprintf( "%02d", $SearchProfileData{"TicketCloseTimeStart$_"} );
            }
            for (qw(Month Day)) {
                $SearchProfileData{"TicketCloseTimeStop$_"}
                    = sprintf( "%02d", $SearchProfileData{"TicketCloseTimeStop$_"} );
            }
            if (
                $SearchProfileData{TicketCloseTimeStartDay}
                && $SearchProfileData{TicketCloseTimeStartMonth}
                && $SearchProfileData{TicketCloseTimeStartYear}
                )
            {
                $SearchProfileData{TicketCloseTimeNewerDate}
                    = $SearchProfileData{TicketCloseTimeStartYear} . '-'
                    . $SearchProfileData{TicketCloseTimeStartMonth} . '-'
                    . $SearchProfileData{TicketCloseTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $SearchProfileData{TicketCloseTimeStopDay}
                && $SearchProfileData{TicketCloseTimeStopMonth}
                && $SearchProfileData{TicketCloseTimeStopYear}
                )
            {
                $SearchProfileData{TicketCloseTimeOlderDate}
                    = $SearchProfileData{TicketCloseTimeStopYear} . '-'
                    . $SearchProfileData{TicketCloseTimeStopMonth} . '-'
                    . $SearchProfileData{TicketCloseTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $SearchProfileData{CloseTimeSearchType} eq 'TimePoint' ) {
            if (
                $SearchProfileData{TicketCloseTimePoint}
                && $SearchProfileData{TicketCloseTimePointStart}
                && $SearchProfileData{TicketCloseTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $SearchProfileData{TicketCloseTimePointFormat} eq 'minute' ) {
                    $Time = $SearchProfileData{TicketCloseTimePoint};
                }
                elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'hour' ) {
                    $Time = $SearchProfileData{TicketCloseTimePoint} * 60;
                }
                elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'day' ) {
                    $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24;
                }
                elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'week' ) {
                    $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24 * 7;
                }
                elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'month' ) {
                    $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24 * 30;
                }
                elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'year' ) {
                    $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24 * 365;
                }
                if ( $SearchProfileData{TicketCloseTimePointStart} eq 'Before' ) {
                    $SearchProfileData{TicketCloseTimeOlderMinutes} = $Time;
                }
                else {
                    $SearchProfileData{TicketCloseTimeNewerMinutes} = $Time;
                }
            }
        }

        # prepare fulltext search
        if ( $SearchProfileData{Fulltext} ) {
            $SearchProfileData{ContentSearch} = 'OR';
            for (qw(From To Cc Subject Body)) {
                $SearchProfileData{$_} = $SearchProfileData{Fulltext};
            }
        }

        # add search prefix and suffix if configured
        my $SearchConfig = $Kernel::OM->Get('Kernel::Config')
            ->Get('Ticket::Frontend::AgentTicketSearch');
        $SearchProfileData{ConditionInline}     = $SearchConfig->{ExtendedSearchCondition};
        $SearchProfileData{ContentSearchPrefix} = '*';
        $SearchProfileData{ContentSearchSuffix} = '*';

        # remove params of ALL filter from summary
        foreach my $Attr ( keys %{ $TicketSearchSummary{All} } ) {
            delete $TicketSearchSummary{All}->{$Attr};
        }

        # check archive flags
        $SearchProfileData{ArchiveFlags} = ['n'];
        if (
            defined $SearchProfileData{SearchInArchive}
            && $SearchProfileData{SearchInArchive} eq 'AllTickets'
            )
        {
            $SearchProfileData{ArchiveFlags} = [ 'y', 'n' ];
        }
        elsif (
            defined $SearchProfileData{SearchInArchive}
            && $SearchProfileData{SearchInArchive} eq 'ArchivedTickets'
            )
        {
            $SearchProfileData{ArchiveFlags} = ['y'];
        }
    }

    %TicketSearch = (
        %TicketSearch,
        %SearchProfileData
    );
    my $SearchParamsAvailable = ( scalar( keys %TicketSearch ) > 2 );

    # EO KIX4OTRS-capeIT

    # check cache
    my $TicketIDs = $CacheObject->Get(
        Type => 'Dashboard',
        Key  => $CacheKey . '-' . $Self->{Filter} . '-List',
    );

    # find and show ticket list
    my $CacheUsed = 1;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # KIX4OTRS-capeIT
    #    if ( !$TicketIDs ) {
    if ( $SearchParamsAvailable && !$TicketIDs ) {

        # EO KIX4OTRS-capeIT

        # quote all CustomerIDs
        if ( $TicketSearch{CustomerID} ) {
            $TicketSearch{CustomerID} = $Kernel::OM->Get('Kernel::System::DB')->QueryStringEscape(
                QueryString => $TicketSearch{CustomerID},
            );
        }

        # add sort by parameter to the search
        if (
            !defined $TicketSearch{SortBy}
            || !$Self->{ValidSortableColumns}->{ $TicketSearch{SortBy} }
            )
        {
            if ( $Self->{SortBy} && $Self->{ValidSortableColumns}->{ $Self->{SortBy} } ) {
                $TicketSearch{SortBy} = $Self->{SortBy};
            }
            else {
                $TicketSearch{SortBy} = 'Age';
            }
        }

        # add order by parameter to the search
        if ( $Self->{OrderBy} ) {
            $TicketSearch{OrderBy} = $Self->{OrderBy};
        }

        # add process management search terms
        if ( $Self->{Config}->{IsProcessWidget} ) {
            $TicketSearch{ 'DynamicField_' . $Self->{ProcessManagementProcessID} } = {
                Like => $Self->{ProcessList},
            };
        }

        # KIX4OTRS-capeIT
        my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
        my %AttributeLookup;
        $SearchProfileData{ShownAttributes} = $SearchProfileData{ShownAttributes} || '';
        my @ShownAttributes = split( /;/, $SearchProfileData{ShownAttributes} );

        # create attibute lookup table
        for my $Attribute (@ShownAttributes) {
            $AttributeLookup{$Attribute} = 1;
        }

        # dynamic fields search parameters for ticket search
        my %DynamicFieldSearchParameters;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # get search field preferences
            my $SearchFieldPreferences = $BackendObject->SearchFieldPreferences(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            next DYNAMICFIELD if !IsArrayRefWithData($SearchFieldPreferences);

            PREFERENCE:
            for my $Preference ( @{$SearchFieldPreferences} ) {

                if (
                    !$AttributeLookup{
                        'LabelSearch_DynamicField_'
                            . $DynamicFieldConfig->{Name}
                            . $Preference->{Type}
                    }
                    )
                {
                    next PREFERENCE;
                }

                # extract the dynamic field value from the profile
                my $SearchParameter = $BackendObject->SearchFieldParameterBuild(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Profile            => \%SearchProfileData,
                    LayoutObject       => $LayoutObject,
                    Type               => $Preference->{Type},
                );

                # set search parameter
                if ( defined $SearchParameter ) {
                    $DynamicFieldSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
                        = $SearchParameter->{Parameter};
                }
            }
        }

        # EO KIX4OTRS-capeIT

        $CacheUsed = 0;
        my @TicketIDsArray;
        if (
            !$Self->{Config}->{IsProcessWidget}
            || IsArrayRefWithData( $Self->{ProcessList} )
            )
        {
            @TicketIDsArray = $TicketObject->TicketSearch(
                Result => 'ARRAY',
                %TicketSearch,
                %{ $TicketSearchSummary{ $Self->{Filter} } },

                # KIX4OTRS-capeIT
                %SearchProfileData,
                %DynamicFieldSearchParameters,

                # EO KIX4OTRS-capeIT

                %{ $Self->{ColumnFilter} },
                Limit => $Self->{PageShown} + $Self->{StartHit} - 1,
            );
        }
        $TicketIDs = \@TicketIDsArray;
    }

    # check cache
    my $Summary = $CacheObject->Get(
        Type => 'Dashboard',
        Key  => $CacheKey . '-Summary',
    );

    # if no cache or new list result, do count lookup
    # KIX4OTRS-capeIT
    #    if ( !$Summary || !$CacheUsed ) {
    if ( $SearchParamsAvailable && ( !$Summary || !$CacheUsed ) ) {

        # EO KIX4OTRS-capeIT
        for my $Type ( sort keys %TicketSearchSummary ) {
            next TYPE if !$TicketSearchSummary{$Type};

            # copy original column filter
            my %ColumnFilter = %{ $Self->{ColumnFilter} || {} };

            # loop through all column filter elements
            for my $Element ( sort keys %ColumnFilter ) {

                # verify if current column filter element is already present in the ticket search
                # summary, to delete it from the column filter hash
                if ( $TicketSearchSummary{$Type}->{$Element} ) {
                    delete $ColumnFilter{$Element};
                }
            }

            # add process management search terms
            if ( $Self->{Config}->{IsProcessWidget} ) {
                $TicketSearch{ 'DynamicField_' . $Self->{ProcessManagementProcessID} } = {
                    Like => $Self->{ProcessList},
                };
            }

            $Summary->{$Type} = 0;

            if (
                !$Self->{Config}->{IsProcessWidget}
                || IsArrayRefWithData( $Self->{ProcessList} )
                )
            {

                # KIX4OTRS-capeIT
                my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
                my %AttributeLookup;
                $SearchProfileData{ShownAttributes} = $SearchProfileData{ShownAttributes} || '';
                my @ShownAttributes = split( /;/, $SearchProfileData{ShownAttributes} );

                # create attibute lookup table
                for my $Attribute (@ShownAttributes) {
                    $AttributeLookup{$Attribute} = 1;
                }

                # dynamic fields search parameters for ticket search
                my %DynamicFieldSearchParameters;

                # cycle trough the activated Dynamic Fields for this screen
                DYNAMICFIELD:
                for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                    next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                    # get search field preferences
                    my $SearchFieldPreferences = $BackendObject->SearchFieldPreferences(
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next DYNAMICFIELD if !IsArrayRefWithData($SearchFieldPreferences);

                    PREFERENCE:
                    for my $Preference ( @{$SearchFieldPreferences} ) {

                        if (
                            !$AttributeLookup{
                                'LabelSearch_DynamicField_'
                                    . $DynamicFieldConfig->{Name}
                                    . $Preference->{Type}
                            }
                            )
                        {
                            next PREFERENCE;
                        }

                        # extract the dynamic field value from the profile
                        my $SearchParameter = $BackendObject->SearchFieldParameterBuild(
                            DynamicFieldConfig => $DynamicFieldConfig,
                            Profile            => \%SearchProfileData,
                            LayoutObject       => $LayoutObject,
                            Type               => $Preference->{Type},
                        );

                        # set search parameter
                        if ( defined $SearchParameter ) {
                            $DynamicFieldSearchParameters{
                                'DynamicField_'
                                    . $DynamicFieldConfig->{Name}
                                }
                                = $SearchParameter->{Parameter};
                        }
                    }
                }

                # EO KIX4OTRS-capeIT

                $Summary->{$Type} = $TicketObject->TicketSearch(
                    Result => 'COUNT',
                    %TicketSearch,
                    %{ $TicketSearchSummary{$Type} },
                    %{ $Self->{ColumnFilter} },
                    %ColumnFilter,
                    %DynamicFieldSearchParameters,
                );
            }
        }
    }

    # set cache
    if ( !$CacheUsed && $Self->{Config}->{CacheTTLLocal} ) {
        $CacheObject->Set(
            Type  => 'Dashboard',
            Key   => $CacheKey . '-Summary',
            Value => $Summary,
            TTL   => $Self->{Config}->{CacheTTLLocal} * 60,
        );
        $CacheObject->Set(
            Type  => 'Dashboard',
            Key   => $CacheKey . '-' . $Self->{Filter} . '-List',
            Value => $TicketIDs,
            TTL   => $Self->{Config}->{CacheTTLLocal} * 60,
        );
    }

    # set css class
    $Summary->{ $Self->{Filter} . '::Selected' } = 'Selected';

    # KIX4OTRS-capeIT
    # get layout object - moved upwards
    # my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    # EO KIX4OTRS-capeIT

    # get filter ticket counts
    $LayoutObject->Block(
        Name => 'ContentLargeTicketGenericFilter',
        Data => {
            %Param,
            %{ $Self->{Config} },
            Name => $Self->{Name},
            %{$Summary},
        },
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # show also watcher if feature is enabled and there is a watcher filter
    if ( $ConfigObject->Get('Ticket::Watcher') && $TicketSearchSummary{Watcher} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericFilterWatcher',
            Data => {
                %Param,
                %{ $Self->{Config} },
                Name => $Self->{Name},
                %{$Summary},
            },
        );
    }

    # show also responsible if feature is enabled and there is a responsible filter
    if ( $ConfigObject->Get('Ticket::Responsible') && $TicketSearchSummary{Responsible} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericFilterResponsible',
            Data => {
                %Param,
                %{ $Self->{Config} },
                Name => $Self->{Name},
                %{$Summary},
            },
        );
    }

    # show only my queues if we have the filter
    if ( $TicketSearchSummary{MyQueues} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericFilterMyQueues',
            Data => {
                %Param,
                %{ $Self->{Config} },
                Name => $Self->{Name},
                %{$Summary},
            },
        );
    }

    # show only my services if we have the filter
    if ( $TicketSearchSummary{MyServices} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericFilterMyServices',
            Data => {
                %Param,
                %{ $Self->{Config} },
                Name => $Self->{Name},
                %{$Summary},
            },
        );
    }

    # show only locked if we have the filter
    if ( $TicketSearchSummary{Locked} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericFilterLocked',
            Data => {
                %Param,
                %{ $Self->{Config} },
                Name => $Self->{Name},
                %{$Summary},
            },
        );
    }

    # add page nav bar
    my $Total = $Summary->{ $Self->{Filter} } || 0;

    my %GetColumnFilter = $Self->{GetColumnFilter} ? %{ $Self->{GetColumnFilter} } : ();

    my $ColumnFilterLink = '';
    COLUMNNAME:
    for my $ColumnName ( sort keys %GetColumnFilter ) {
        next COLUMNNAME if !$ColumnName;
        next COLUMNNAME if !$GetColumnFilter{$ColumnName};
        $ColumnFilterLink
            .= ';' . $LayoutObject->Ascii2Html( Text => 'ColumnFilter' . $ColumnName )
            . '=' . $LayoutObject->Ascii2Html( Text => $GetColumnFilter{$ColumnName} )
    }

    my $LinkPage =
        'Subaction=Element;Name=' . $Self->{Name}
        . ';Filter=' . $Self->{Filter}
        . ';SortBy=' .  ( $Self->{SortBy}  || '' )
        . ';OrderBy=' . ( $Self->{OrderBy} || '' )
        . $ColumnFilterLink
        . ';';

    if ( $Param{CustomerID} ) {
        $LinkPage .= "CustomerID=$Param{CustomerID};";
    }
    my %PageNav = $LayoutObject->PageNavBar(
        StartHit       => $Self->{StartHit},
        PageShown      => $Self->{PageShown},
        AllHits        => $Total || 1,
        Action         => 'Action=' . $LayoutObject->{Action},
        Link           => $LinkPage,
        AJAXReplace    => 'Dashboard' . $Self->{Name},
        IDPrefix       => 'Dashboard' . $Self->{Name},
        KeepScriptTags => $Param{AJAX},
    );
    $LayoutObject->Block(
        Name => 'ContentLargeTicketGenericFilterNavBar',
        Data => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
            %PageNav,
        },
    );

    # show table header
    $LayoutObject->Block(
        Name => 'ContentLargeTicketGenericHeader',
        Data => {},
    );

    # define which meta items will be shown
    my @MetaItems = $LayoutObject->TicketMetaItemsCount();

    # show non-labeled table headers
    my $CSS = '';
    my $OrderBy;
    for my $Item (@MetaItems) {
        $CSS = '';
        my $Title = $Item;
        if ( $Self->{SortBy} && ( $Self->{SortBy} eq $Item ) ) {
            if ( $Self->{OrderBy} && ( $Self->{OrderBy} eq 'Up' ) ) {
                $OrderBy = 'Down';
                # KIX4OTRS-capeIT
                # $CSS .= ' SortAscendingLarge';
                $CSS .= ' SortDescendingLarge';
                # EO KIX4OTRS-capeIT
            }
            else {
                $OrderBy = 'Up';
                # KIX4OTRS-capeIT
                # $CSS .= ' SortDescendingLarge';
                $CSS .= ' SortAscendingLarge';
                # EO KIX4OTRS-capeIT
            }

            # set title description
            # KIX4OTRS-capeIT
            # my $TitleDesc = $OrderBy eq 'Down' ? Translatable('sorted ascending') : Translatable('sorted descending');
            my $TitleDesc = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
            # EO KIX4OTRS-capeIT
            $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
            $Title .= ', ' . $TitleDesc;
        }

        # add surrounding container
        $LayoutObject->Block(
            Name => 'GeneralOverviewHeader',
        );
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericHeaderMeta',
            Data => {
                CSS => $CSS,
            },
        );

        if ( $Item eq 'New Article' ) {

            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericHeaderMetaEmpty',
                Data => {
                    HeaderColumnName => $Item,
                },
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericHeaderMetaLink',
                Data => {
                    %Param,
                    Name             => $Self->{Name},
                    OrderBy          => $OrderBy || 'Up',
                    HeaderColumnName => $Item,
                    Title            => $Title,
                },
            );
        }
    }

    # show all needed headers
    HEADERCOLUMN:
    for my $HeaderColumn (@Columns) {

        # skip CustomerID if Customer Information Center
        if (
            $Self->{Action} eq 'AgentCustomerInformationCenter'
            && $HeaderColumn eq 'CustomerID'
            )
        {
            next HEADERCOLUMN;
        }

        if ( $HeaderColumn !~ m{\A DynamicField_}xms ) {

            $CSS = '';
            my $Title = $LayoutObject->{LanguageObject}->Translate($HeaderColumn);

            if ( $Self->{SortBy} && ( $Self->{SortBy} eq $HeaderColumn ) ) {
                if ( $Self->{OrderBy} && ( $Self->{OrderBy} eq 'Up' ) ) {
                    $OrderBy = 'Down';
                    # KIX4OTRS-capeIT
                    # $CSS .= ' SortAscendingLarge';
                    $CSS .= ' SortDescendingLarge';
                    # EO KIX4OTRS-capeIT
                }
                else {
                    $OrderBy = 'Up';
                    # KIX4OTRS-capeIT
                    # $CSS .= ' SortDescendingLarge';
                    $CSS .= ' SortAscendingLarge';
                    # EO KIX4OTRS-capeIT
                }

                # add title description
                # KIX4OTRS-capeIT
                # my $TitleDesc = $OrderBy eq 'Down' ? Translatable('sorted ascending') : Translatable('sorted descending');
                my $TitleDesc = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
                # EO KIX4OTRS-capeIT
                $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
                $Title .= ', ' . $TitleDesc;
            }

            # translate the column name to write it in the current language
            my $TranslatedWord;
            if ( $HeaderColumn eq 'EscalationTime' ) {
                $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Service Time');
            }
            elsif ( $HeaderColumn eq 'EscalationResponseTime' ) {
                $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('First Response Time');
            }
            elsif ( $HeaderColumn eq 'EscalationSolutionTime' ) {
                $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Solution Time');
            }
            elsif ( $HeaderColumn eq 'EscalationUpdateTime' ) {
                $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Update Time');
            }
            elsif ( $HeaderColumn eq 'PendingTime' ) {
                $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Pending till');
            }
            else {
                $TranslatedWord = $LayoutObject->{LanguageObject}->Translate($HeaderColumn);
            }

            # add surrounding container
            $LayoutObject->Block(
                Name => 'GeneralOverviewHeader',
            );
            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericHeaderTicketHeader',
                Data => {},
            );

            if ( $HeaderColumn eq 'TicketNumber' ) {
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderTicketNumberColumn',
                    Data => {
                        %Param,
                        CSS => $CSS || '',
                        Name    => $Self->{Name},
                        OrderBy => $OrderBy || 'Up',
                        Filter  => $Self->{Filter},
                        Title   => $Title,
                    },
                );
                next HEADERCOLUMN;
            }

            my $FilterTitle     = $TranslatedWord;
            my $FilterTitleDesc = Translatable('filter not active');
            if ( $Self->{GetColumnFilterSelect} && $Self->{GetColumnFilterSelect}->{$HeaderColumn} )
            {
                $CSS .= ' FilterActive';
                $FilterTitleDesc = Translatable('filter active');
            }
            $FilterTitleDesc = $LayoutObject->{LanguageObject}->Translate($FilterTitleDesc);
            $FilterTitle .= ', ' . $FilterTitleDesc;

            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericHeaderColumn',
                Data => {
                    HeaderColumnName     => $HeaderColumn   || '',
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    CSS                  => $CSS            || '',
                },
            );

            # verify if column is filterable and sortable
            if (
                $Self->{ValidSortableColumns}->{$HeaderColumn}
                && $Self->{ValidFilterableColumns}->{$HeaderColumn}
                )
            {

                my $Css;
                if (
                    $HeaderColumn eq 'CustomerID'
                    || $HeaderColumn eq 'Responsible'
                    || $HeaderColumn eq 'Owner'
                    )
                {
                    $Css = 'Hidden';
                }

                # variable to save the filter's HTML code
                my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                    ColumnName => $HeaderColumn,
                    Css        => $Css,
                );

                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumnFilterLink',
                    Data => {
                        %Param,
                        HeaderColumnName     => $HeaderColumn,
                        CSS                  => $CSS,
                        HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                        ColumnFilterStrg     => $ColumnFilterHTML,
                        OrderBy              => $OrderBy || 'Up',
                        SortBy               => $Self->{SortBy} || 'Age',
                        Name                 => $Self->{Name},
                        Title                => $Title,
                        FilterTitle          => $FilterTitle,
                    },
                );

                if ( $HeaderColumn eq 'CustomerID' ) {

                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericHeaderColumnFilterLinkCustomerIDSearch',
                        Data => {
                            minQueryLength      => 2,
                            queryDelay          => 100,
                            maxResultsDisplayed => 20,
                        },
                    );
                }
                elsif ( $HeaderColumn eq 'Responsible' || $HeaderColumn eq 'Owner' ) {

                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericHeaderColumnFilterLinkUserSearch',
                        Data => {
                            minQueryLength      => 2,
                            queryDelay          => 100,
                            maxResultsDisplayed => 20,
                        },
                    );
                }
            }

            # verify if column is just filterable
            elsif ( $Self->{ValidFilterableColumns}->{$HeaderColumn} ) {

                my $Css;
                if ( $HeaderColumn eq 'CustomerUserID' ) {
                    $Css = 'Hidden';
                }

                # variable to save the filter's HTML code
                my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                    ColumnName => $HeaderColumn,
                    Css        => $Css,
                );

                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumnFilter',
                    Data => {
                        %Param,
                        HeaderColumnName     => $HeaderColumn,
                        CSS                  => $CSS,
                        HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                        ColumnFilterStrg     => $ColumnFilterHTML,
                        Name                 => $Self->{Name},
                        Title                => $Title,
                        FilterTitle          => $FilterTitle,
                    },
                );

                if ( $HeaderColumn eq 'CustomerUserID' ) {

                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericHeaderColumnFilterLinkCustomerUserSearch',
                        Data => {
                            minQueryLength      => 2,
                            queryDelay          => 100,
                            maxResultsDisplayed => 20,
                        },
                    );
                }
            }

            # verify if column is just sortable
            elsif ( $Self->{ValidSortableColumns}->{$HeaderColumn} ) {
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumnLink',
                    Data => {
                        %Param,
                        HeaderColumnName     => $HeaderColumn,
                        CSS                  => $CSS,
                        HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                        OrderBy              => $OrderBy || 'Up',
                        SortBy               => $Self->{SortBy} || $HeaderColumn,
                        Name                 => $Self->{Name},
                        Title                => $Title,
                    },
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumnEmpty',
                    Data => {
                        %Param,
                        HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                        HeaderColumnName     => $HeaderColumn,
                        CSS                  => $CSS,
                        Title                => $Title,
                    },
                );
            }
        }

        # Dynamic fields
        else {
            my $DynamicFieldConfig;
            my $DFColumn = $HeaderColumn;
            $DFColumn =~ s/DynamicField_//g;
            DYNAMICFIELD:
            for my $DFConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
                next DYNAMICFIELD if $DFConfig->{Name} ne $DFColumn;

                $DynamicFieldConfig = $DFConfig;
                last DYNAMICFIELD;
            }
            next HEADERCOLUMN if !IsHashRefWithData($DynamicFieldConfig);

            my $Label = $DynamicFieldConfig->{Label};

            my $TranslatedLabel = $LayoutObject->{LanguageObject}->Translate($Label);

            my $DynamicFieldName = 'DynamicField_' . $DynamicFieldConfig->{Name};

            my $CSS             = '';
            my $FilterTitle     = $Label;
            my $FilterTitleDesc = Translatable('filter not active');
            if (
                $Self->{GetColumnFilterSelect}
                && defined $Self->{GetColumnFilterSelect}->{$DynamicFieldName}
                )
            {
                $CSS .= 'FilterActive ';
                $FilterTitleDesc = Translatable('filter active');
            }
            $FilterTitleDesc = $LayoutObject->{LanguageObject}->Translate($FilterTitleDesc);
            $FilterTitle .= ', ' . $FilterTitleDesc;

            # get field sortable condition
            my $IsSortable = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsSortable',
            );

            # set title
            my $Title = $Label;

            # add surrounding container
            $LayoutObject->Block(
                Name => 'GeneralOverviewHeader',
            );
            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericHeaderTicketHeader',
                Data => {},
            );

            if ($IsSortable) {
                my $OrderBy;
                if (
                    $Self->{SortBy}
                    && ( $Self->{SortBy} eq ( 'DynamicField_' . $DynamicFieldConfig->{Name} ) )
                    )
                {
                    if ( $Self->{OrderBy} && ( $Self->{OrderBy} eq 'Up' ) ) {
                        $OrderBy = 'Down';
                        # KIX4OTRS-capeIT
                        # $CSS .= ' SortAscendingLarge';
                        $CSS .= ' SortDescendingLarge';
                        # EO KIX4OTRS-capeIT
                    }
                    else {
                        $OrderBy = 'Up';
                        # KIX4OTRS-capeIT
                        # $CSS .= ' SortDescendingLarge';
                        $CSS .= ' SortAscendingLarge';
                        # EO KIX4OTRS-capeIT
                    }

                    # add title description
                    # KIX4OTRS-capeIT
                    # my $TitleDesc = $OrderBy eq 'Down' ? 'sorted ascending' : 'sorted descending';
                    my $TitleDesc = $OrderBy eq 'Down' ? 'sorted descending' : 'sorted ascending';
                    # EO KIX4OTRS-capeIT
                    $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
                    $Title .= ', ' . $TitleDesc;
                }

                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumn',
                    Data => {
                        HeaderColumnName => $DynamicFieldName || '',
                        CSS => $CSS || '',
                    },
                );

                # check if the dynamic field is sortable and filterable (sortable check was made before)
                if ( $Self->{ValidFilterableColumns}->{$DynamicFieldName} ) {

                    # variable to save the filter's HTML code
                    my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                        ColumnName => $DynamicFieldName,
                        Label      => $Label,
                    );

                    # output sortable and filterable dynamic field
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericHeaderColumnFilterLink',
                        Data => {
                            %Param,
                            HeaderColumnName     => $DynamicFieldName,
                            CSS                  => $CSS,
                            HeaderNameTranslated => $TranslatedLabel || $DynamicFieldName,
                            ColumnFilterStrg     => $ColumnFilterHTML,
                            OrderBy              => $OrderBy || 'Up',
                            SortBy               => $Self->{SortBy} || 'Age',
                            Name                 => $Self->{Name},
                            Title                => $Title,
                            FilterTitle          => $FilterTitle,
                        },
                    );
                }

                # otherwise the dynamic field is only sortable (sortable check was made before)
                else {

                    # output sortable dynamic field
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericHeaderColumnLink',
                        Data => {
                            %Param,
                            HeaderColumnName     => $DynamicFieldName,
                            CSS                  => $CSS,
                            HeaderNameTranslated => $TranslatedLabel || $DynamicFieldName,
                            OrderBy              => $OrderBy || 'Up',
                            SortBy               => $Self->{SortBy} || $DynamicFieldName,
                            Name                 => $Self->{Name},
                            Title                => $Title,
                            FilterTitle          => $FilterTitle,
                        },
                    );
                }
            }

            # if the dynamic field was not sortable (check was made and fail before)
            # it might be filterable
            elsif ( $Self->{ValidFilterableColumns}->{$DynamicFieldName} ) {

                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumn',
                    Data => {
                        HeaderColumnName => $DynamicFieldName || '',
                        CSS              => $CSS              || '',
                        Title            => $Title,
                    },
                );

                # variable to save the filter's HTML code
                my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                    ColumnName => $DynamicFieldName,
                    Label      => $Label,
                );

                # output filterable (not sortable) dynamic field
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumnFilter',
                    Data => {
                        %Param,
                        HeaderColumnName     => $DynamicFieldName,
                        CSS                  => $CSS,
                        HeaderNameTranslated => $TranslatedLabel || $DynamicFieldName,
                        ColumnFilterStrg     => $ColumnFilterHTML,
                        Name                 => $Self->{Name},
                        Title                => $Title,
                        FilterTitle          => $FilterTitle,
                    },
                );
            }

            # otherwise the field is not filterable and not sortable
            else {

                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumn',
                    Data => {
                        HeaderColumnName => $DynamicFieldName || '',
                        CSS => $CSS || '',
                    },
                );

                # output plain dynamic field header (not filterable, not sortable)
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericHeaderColumnEmpty',
                    Data => {
                        %Param,
                        HeaderNameTranslated => $TranslatedLabel || $DynamicFieldName,
                        HeaderColumnName     => $DynamicFieldName,
                        CSS                  => $CSS,
                        Title                => $Title,
                    },
                );
            }
        }
    }

    # KIX4OTRS-capeIT
    if ( $Self->{Name} =~ /SearchTemplate/ && !$Self->{SearchTemplateName} ) {
        $TicketIDs = [];
    }
    my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );

    # EO KIX4OTRS-capeIT

    # show tickets
    my $Count = 0;
    TICKETID:
    for my $TicketID ( @{$TicketIDs} ) {
        $Count++;
        next TICKETID if $Count < $Self->{StartHit};
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            UserID        => $Self->{UserID},
            DynamicFields => 0,
            Silent        => 1
        );

        next TICKETID if !%Ticket;

        # set a default title if ticket has no title
        if ( !$Ticket{Title} ) {
            $Ticket{Title} = $LayoutObject->{LanguageObject}->Translate(
                'This ticket has no title or subject'
            );
        }

        my $WholeTitle = $Ticket{Title} || '';
        $Ticket{Title} = $TicketObject->TicketSubjectClean(
            TicketNumber => $Ticket{TicketNumber},
            Subject      => $Ticket{Title},
        );

        # create human age
        if ( $Self->{Config}->{Time} ne 'Age' ) {
            $Ticket{Time} = $LayoutObject->CustomerAgeInHours(
                Age   => $Ticket{ $Self->{Config}->{Time} },
                Space => ' ',
            );
        }
        else {
            $Ticket{Time} = $LayoutObject->CustomerAge(
                Age   => $Ticket{ $Self->{Config}->{Time} },
                Space => ' ',
            );
        }

        # KIX4OTRS-capeIT
        my $StateHighlighting
            = $Kernel::OM->Get('Kernel::Config')
            ->Get('KIX4OTRSTicketOverviewSmallHighlightMapping');
        if (
            $StateHighlighting
            && ref($StateHighlighting) eq 'HASH'
            && $StateHighlighting->{ $Ticket{State} }
            )
        {
            $Ticket{LineStyle} = $StateHighlighting->{ $Ticket{State} };
        }

        # EO KIX4OTRS-capeIT

        # show ticket
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericRow',
            Data => \%Ticket,
        );

        # KIX4OTRS-capeIT
        # highlight tickets, which are escalated
        my $EscHighlightClass = '';
        if ( $Ticket{SolutionTimeEscalation} || $Ticket{FirstResponseTimeEscalation} ) {
            $EscHighlightClass = 'EscTime';
        }

        # EO KIX4OTRS-capeIT

        # show ticket flags
        my @TicketMetaItems = $LayoutObject->TicketMetaItems(
            Ticket => \%Ticket,
        );
        for my $Item (@TicketMetaItems) {

            $LayoutObject->Block(
                Name => 'GeneralOverviewRow',
            );
            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericRowMeta',

                # KIX4OTRS-capeIT
                # Data => {},
                Data => {
                    ClassTable => $EscHighlightClass,
                },

                # EO KIX4OTRS-capeIT
            );
            if ($Item) {
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericRowMetaImage',
                    Data => $Item,
                );
            }
        }

        # save column content
        my $DataValue;

        # get needed objects
        my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
        my $UserObject    = $Kernel::OM->Get('Kernel::System::User');

        # show all needed columns
        COLUMN:
        for my $Column (@Columns) {

            # skip CustomerID if Customer Information Center
            if (
                $Self->{Action} eq 'AgentCustomerInformationCenter'
                && $Column eq 'CustomerID'
                )
            {
                next COLUMN;
            }

            if ( $Column !~ m{\A DynamicField_}xms ) {

                $LayoutObject->Block(
                    Name => 'GeneralOverviewRow',
                );
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericTicketColumn',
                    Data => {},
                );

                my $BlockType = '';
                my $CSSClass  = '';

                if ( $Column eq 'TicketNumber' ) {
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericTicketNumber',
                        Data => {
                            %Ticket,
                            Title => $Ticket{Title},
                        },
                    );
                    next COLUMN;
                }

                # KIX4OTRS-capeIT
                elsif ( $Column eq 'Queue' ) {
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericDynamicField',
                        Data => {
                            Title => $Ticket{Queue}
                        },
                    );
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericDynamicFieldLink',
                        Data => {
                            Value => $Ticket{Queue},
                            Link  => $LayoutObject->{Baselink} . 'Action=AgentTicketQueue;QueueID='
                                . $Ticket{QueueID}
                        },
                    );

                    next COLUMN;
                }

                # EO KIX4OTRS-capeIT
                elsif ( $Column eq 'EscalationTime' ) {
                    my %EscalationData;
                    $EscalationData{EscalationTime}            = $Ticket{EscalationTime};
                    $EscalationData{EscalationDestinationDate} = $Ticket{EscalationDestinationDate};

                    $EscalationData{EscalationTimeHuman} = $LayoutObject->CustomerAgeInHours(
                        Age   => $EscalationData{EscalationTime},
                        Space => ' ',
                    );
                    $EscalationData{EscalationTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
                        Age   => $EscalationData{EscalationTimeWorkingTime},
                        Space => ' ',
                    );
                    if ( defined $Ticket{EscalationTime} && $Ticket{EscalationTime} < 60 * 60 * 1 )
                    {
                        $EscalationData{EscalationClass} = 'Warning';
                    }
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericEscalationTime',
                        Data => {%EscalationData},
                    );
                    next COLUMN;

                    $DataValue = $LayoutObject->CustomerAge(
                        Age   => $Ticket{'EscalationTime'},
                        Space => ' '
                    );
                }
                elsif ( $Column eq 'Age' ) {
                    $DataValue = $LayoutObject->CustomerAge(
                        Age   => $Ticket{Age},
                        Space => ' ',
                    );
                }
                elsif ( $Column eq 'EscalationSolutionTime' ) {
                    $BlockType = 'Escalation';
                    $DataValue = $LayoutObject->CustomerAgeInHours(
                        Age => $Ticket{SolutionTime} || 0,
                        Space => ' ',
                    );
                    if ( defined $Ticket{SolutionTime} && $Ticket{SolutionTime} < 60 * 60 * 1 ) {
                        $CSSClass = 'Warning';
                    }
                }
                elsif ( $Column eq 'EscalationResponseTime' ) {
                    $BlockType = 'Escalation';
                    $DataValue = $LayoutObject->CustomerAgeInHours(
                        Age => $Ticket{FirstResponseTime} || 0,
                        Space => ' ',
                    );
                    if (
                        defined $Ticket{FirstResponseTime}
                        && $Ticket{FirstResponseTime} < 60 * 60 * 1
                        )
                    {
                        $CSSClass = 'Warning';
                    }
                }
                elsif ( $Column eq 'EscalationUpdateTime' ) {
                    $BlockType = 'Escalation';
                    $DataValue = $LayoutObject->CustomerAgeInHours(
                        Age => $Ticket{UpdateTime} || 0,
                        Space => ' ',
                    );
                    if ( defined $Ticket{UpdateTime} && $Ticket{UpdateTime} < 60 * 60 * 1 ) {
                        $CSSClass = 'Warning';
                    }
                }
                elsif ( $Column eq 'PendingTime' ) {
                    $BlockType = 'Escalation';

                    # KIX4OTRS-capeIT
                    my $DisplayPendingTime = $UserPreferences{UserDisplayPendingTime} || '';

                    if ( $DisplayPendingTime && $DisplayPendingTime eq 'RemainingTime' ) {

                        # EO KIX4OTRS-capeIT
                        $DataValue = $LayoutObject->CustomerAge(
                            Age   => $Ticket{'UntilTime'},
                            Space => ' '
                        );

                        # KIX4OTRS-capeIT
                    }
                    elsif ( defined $Ticket{UntilTime} && $Ticket{UntilTime} ) {
                        $DataValue = $Kernel::OM->Get('Kernel::System::Time')
                            ->SystemTime2TimeStamp(
                            SystemTime => $Ticket{RealTillTimeNotUsed},
                            );
                        $DataValue = $LayoutObject->{LanguageObject}
                            ->FormatTimeString( $DataValue, 'DateFormat' );
                    }
                    else {
                        $DataValue = '';
                    }

                    # EO KIX4OTRS-capeIT

                    if ( defined $Ticket{UntilTime} && $Ticket{UntilTime} < -1 ) {
                        $CSSClass = 'Warning';
                    }
                }
                elsif ( $Column eq 'Owner' ) {

                    # get owner info
                    my %OwnerInfo = $UserObject->GetUserData(
                        UserID => $Ticket{OwnerID},
                    );
                    $DataValue = $OwnerInfo{'UserFirstname'} . ' ' . $OwnerInfo{'UserLastname'};
                }
                elsif ( $Column eq 'Responsible' ) {

                    # get responsible info
                    my %ResponsibleInfo = $UserObject->GetUserData(
                        UserID => $Ticket{ResponsibleID},
                    );
                    $DataValue = $ResponsibleInfo{'UserFirstname'} . ' '
                        . $ResponsibleInfo{'UserLastname'};
                }
                elsif (
                    $Column eq 'State'
                    || $Column eq 'Lock'
                    || $Column eq 'Priority'
                    )
                {
                    $BlockType = 'Translatable';
                    $DataValue = $Ticket{$Column};
                }
                elsif ( $Column eq 'Created' || $Column eq 'Changed' ) {
                    $BlockType = 'Time';
                    $DataValue = $Ticket{$Column};
                }
                elsif ( $Column eq 'CustomerName' ) {

                    # get customer name
                    my $CustomerName;
                    if ( $Ticket{CustomerUserID} ) {
                        $CustomerName = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerName(
                            UserLogin => $Ticket{CustomerUserID},
                        );
                    }
                    $DataValue = $CustomerName;
                }
                elsif ( $Column eq 'CustomerCompanyName' ) {
                    my %CustomerCompanyData;
                    if ( $Ticket{CustomerID} ) {
                        %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
                            CustomerID => $Ticket{CustomerID},
                        );
                    }
                    $DataValue = $CustomerCompanyData{CustomerCompanyName};
                }
                else {
                    $DataValue = $Ticket{$Column};
                }

                if ( $Column eq 'Title' ) {
                    $LayoutObject->Block(
                        Name => "ContentLargeTicketTitle",
                        Data => {
                            Title => "$DataValue " || '',
                            WholeTitle => $WholeTitle,
                            Class      => $CSSClass || '',
                        },
                    );

                }
                else {
                    $LayoutObject->Block(
                        Name => "ContentLargeTicketGenericColumn$BlockType",
                        Data => {
                            GenericValue => $DataValue || '',
                            Class        => $CSSClass  || '',
                        },
                    );
                }

            }

            # Dynamic fields
            else {
                my $DynamicFieldConfig;
                my $DFColumn = $Column;
                $DFColumn =~ s/DynamicField_//g;
                DYNAMICFIELD:
                for my $DFConfig ( @{ $Self->{DynamicField} } ) {
                    next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
                    next DYNAMICFIELD if $DFConfig->{Name} ne $DFColumn;

                    $DynamicFieldConfig = $DFConfig;
                    last DYNAMICFIELD;
                }
                next COLUMN if !IsHashRefWithData($DynamicFieldConfig);

                # get field value
                my $Value = $BackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $TicketID,
                );

                my $ValueStrg = $BackendObject->DisplayValueRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Value,
                    ValueMaxChars      => 20,
                    LayoutObject       => $LayoutObject,
                );

                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericDynamicField',
                    Data => {
                        Value => $ValueStrg->{Value},
                        Title => $ValueStrg->{Title},
                    },
                );

                if ( $ValueStrg->{Link} ) {
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericDynamicFieldLink',
                        Data => {
                            Value                       => $ValueStrg->{Value},
                            Title                       => $ValueStrg->{Title},
                            Link                        => $ValueStrg->{Link},
                            $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                        },
                    );
                }
                else {
                    $LayoutObject->Block(
                        Name => 'ContentLargeTicketGenericDynamicFieldPlain',
                        Data => {
                            Value => $ValueStrg->{Value},
                            Title => $ValueStrg->{Title},
                        },
                    );
                }
            }

        }

    }

    # show "none" if no ticket is available
    if ( !$TicketIDs || !@{$TicketIDs} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericNone',
            Data => {},
        );
    }

    # check for refresh time
    my $Refresh = '';
    if ( $Self->{UserRefreshTime} ) {
        $Refresh = 60 * $Self->{UserRefreshTime};
        my $NameHTML = $Self->{Name};
        $NameHTML =~ s{-}{_}xmsg;
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericRefresh',
            Data => {
                %{ $Self->{Config} },
                Name        => $Self->{Name},
                NameHTML    => $NameHTML,
                RefreshTime => $Refresh,
                CustomerID  => $Param{CustomerID},

                # KIX4OTRS-capeIT
                CustomerUserLogin => $Param{CustomerUserLogin},

                # EO KIX4OTRS-capeIT
                %{$Summary},
            },
        );
    }

    # check for active filters and add a 'remove filters' button to the widget header
    if ( $Self->{GetColumnFilterSelect} && IsHashRefWithData( $Self->{GetColumnFilterSelect} ) ) {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericRemoveFilters',
            Data => {
                Name       => $Self->{Name},
                CustomerID => $Param{CustomerID},
            },
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericRemoveFiltersRemove',
            Data => {
                Name => $Self->{Name},
            },
        );
    }

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardTicketGeneric',
        Data         => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
            %{$Summary},
            FilterValue       => $Self->{Filter},
            CustomerID        => $Self->{CustomerID},
            # KIX4OTRS-capeIT
            CustomerUserLogin => $Param{CustomerUserLogin},
            # EO KIX4OTRS-capeIT
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
}

sub _InitialColumnFilter {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Label = $Param{Label} || $Param{ColumnName};
    $Label = $LayoutObject->{LanguageObject}->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => '',
            Value => uc $Label,
        },
    ];

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'State'
        || $Param{ColumnName} eq 'Lock'
        || $Param{ColumnName} eq 'Priority'
        )
    {
        $TranslationOption = 1;
    }

    my $Class = 'ColumnFilter';
    if ( $Param{Css} ) {
        $Class .= ' ' . $Param{Css};
    }

    # build select HTML
    my $ColumnFilterHTML = $LayoutObject->BuildSelection(
        Name        => 'ColumnFilter' . $Param{ColumnName} . $Self->{Name},
        Data        => $Data,
        Class       => $Class,
        Translation => $TranslationOption,
        SelectedID  => '',
    );
    return $ColumnFilterHTML;
}

sub _GetColumnValues {
    my ( $Self, %Param ) = @_;

    return if !IsStringWithData( $Param{HeaderColumn} );

    my $HeaderColumn = $Param{HeaderColumn};
    my %ColumnFilterValues;
    my $TicketIDs;

    if ( IsArrayRefWithData( $Param{OriginalTicketIDs} ) ) {
        $TicketIDs = $Param{OriginalTicketIDs};
    }

    if ( $HeaderColumn !~ m/^DynamicField_/ ) {
        my $FunctionName = $HeaderColumn . 'FilterValuesGet';
        if ( $HeaderColumn eq 'CustomerID' ) {
            $FunctionName = 'CustomerFilterValuesGet';
        }

        $ColumnFilterValues{$HeaderColumn} = $Kernel::OM->Get('Kernel::System::Ticket::ColumnFilter')->$FunctionName(
            TicketIDs    => $TicketIDs,
            HeaderColumn => $HeaderColumn,
            UserID       => $Self->{UserID},
        );
    }
    else {
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $FieldName = 'DynamicField_' . $DynamicFieldConfig->{Name};

            next DYNAMICFIELD if $FieldName ne $HeaderColumn;

            # get dynamic field backend object
            my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

            my $IsFiltrable = $BackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsFiltrable',
            );

            next DYNAMICFIELD if !$IsFiltrable;

            $Self->{ValidFilterableColumns}->{$HeaderColumn} = $IsFiltrable;
            if ( IsArrayRefWithData($TicketIDs) ) {

                # get the historical values for the field
                $ColumnFilterValues{$HeaderColumn} = $BackendObject->ColumnFilterValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    LayoutObject       => $Kernel::OM->Get('Kernel::Output::HTML::Layout'),
                    TicketIDs          => $TicketIDs,
                );
            }
            else {

                # get PossibleValues
                $ColumnFilterValues{$HeaderColumn} = $BackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );
            }
            last DYNAMICFIELD;
        }
    }

    return \%ColumnFilterValues;
}

=over

=item _ColumnFilterJSON()

    creates a JSON select filter for column header

    my $ColumnFilterJSON = $TicketOverviewSmallObject->_ColumnFilterJSON(
        ColumnName => 'Queue',
        Label      => 'Queue',
        ColumnValues => {
            1 => 'PostMaster',
            2 => 'Junk',
        },
        SelectedValue '1',
    );

=cut

sub _ColumnFilterJSON {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Label = $Param{Label};
    $Label =~ s{ \A DynamicField_ }{}gxms;
    $Label = $LayoutObject->{LanguageObject}->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => 'DeleteFilter',
            Value => uc $Label,
        },
        {
            Key      => '-',
            Value    => '-',
            Disabled => 1,
        },
    ];

    if ( $Param{ColumnValues} && ref $Param{ColumnValues} eq 'HASH' ) {

        my %Values = %{ $Param{ColumnValues} };

        # set possible values
        for my $ValueKey ( sort { lc $Values{$a} cmp lc $Values{$b} } keys %Values ) {
            push @{$Data}, {
                Key   => $ValueKey,
                Value => $Values{$ValueKey}
            };
        }
    }

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'State'
        || $Param{ColumnName} eq 'Lock'
        || $Param{ColumnName} eq 'Priority'
        )
    {
        $TranslationOption = 1;
    }

    # build select HTML
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name         => 'ColumnFilter' . $Param{ColumnName} . $Param{DashboardName},
                Data         => $Data,
                Class        => 'ColumnFilter',
                Sort         => 'AlphanumericKey',
                TreeView     => 1,
                SelectedID   => $Param{SelectedValue},
                Translation  => $TranslationOption,
                AutoComplete => 'off',
            },
        ],
    );

    return $JSON;
}

sub _SearchParamsGet {
    my ( $Self, %Param ) = @_;

    # get all search base attributes
    my %TicketSearch;
    my %DynamicFieldsParameters;
    my @Params = split /;/, $Self->{Config}->{Attributes};

    # read user preferences and config to get columns that
    # should be shown in the dashboard widget (the preferences
    # have precedence)
    my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $Self->{UserID},
    );

    # KIX4OTRS-capeIT
    # fallback to use old configuration
    # my $PreferencesColumn = $JSONObject->Decode(
    #     Data => $Preferences{ $Self->{PrefKeyColumns} },
    # );
    my $PreferencesColumn;
    if ( defined $Preferences{ $Self->{PrefKeyColumns} }
        && $Preferences{ $Self->{PrefKeyColumns} } )
    {

        my $ColumnPreferences = $Preferences{ $Self->{PrefKeyColumns} };
        my @OldConfigArray = split( /;/, $ColumnPreferences );

        if ( $ColumnPreferences =~ /^\{\"Columns\".*?\}$/ ) {

            # get column names from Preferences
            $PreferencesColumn = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                Data => $Preferences{ $Self->{PrefKeyColumns} },
            );
        }
        elsif ( scalar @OldConfigArray ) {

            # set default values
            $PreferencesColumn->{Columns}->{TicketNumber} = 1;
            $PreferencesColumn->{Columns}->{Title}        = 1;
            $PreferencesColumn->{Columns}->{Age}          = 1;

            push( @{ $PreferencesColumn->{Order} }, ( 'TicketNumber', 'Title', 'Age' ) );

            # get already set values
            for my $Column (@OldConfigArray) {
                $PreferencesColumn->{Columns}->{$Column} = 1;
                push( @{ $PreferencesColumn->{Order} }, $Column );
            }
        }
    }

    # EO KIX4OTRS-capeIT

    # check for default settings
    my @Columns;
    if (
        $Self->{Config}->{DefaultColumns}
        && IsHashRefWithData( $Self->{Config}->{DefaultColumns} )
        )
    {
        @Columns = grep { $Self->{Config}->{DefaultColumns}->{$_} eq '2' }
            sort { $Self->_DefaultColumnSort() } keys %{ $Self->{Config}->{DefaultColumns} };
    }
    if ($PreferencesColumn) {
        if ( $PreferencesColumn->{Columns} && %{ $PreferencesColumn->{Columns} } ) {
            @Columns = grep {
                defined $PreferencesColumn->{Columns}->{$_}
                    && $PreferencesColumn->{Columns}->{$_} eq '1'
            } sort { $Self->_DefaultColumnSort() } keys %{ $Self->{Config}->{DefaultColumns} };
        }
        if ( $PreferencesColumn->{Order} && @{ $PreferencesColumn->{Order} } ) {
            @Columns = @{ $PreferencesColumn->{Order} };
        }

        # remove duplicate columns
        my %UniqueColumns;
        my @ColumnsEnabledAux;

        for my $Column (@Columns) {
            if ( !$UniqueColumns{$Column} ) {
                push @ColumnsEnabledAux, $Column;
            }
            $UniqueColumns{$Column} = 1;
        }

        # set filtered column list
        @Columns = @ColumnsEnabledAux;
    }

    # always set TicketNumber
    if ( !grep { $_ eq 'TicketNumber' } @Columns ) {
        unshift @Columns, 'TicketNumber';
    }

    # also always set ProcessID and ActivityID (for process widgets)
    if ( $Self->{Config}->{IsProcessWidget} ) {

        my @AlwaysColumns = (
            'DynamicField_' . $Self->{ProcessManagementProcessID},
            'DynamicField_' . $Self->{ProcessManagementActivityID},
        );
        my $Resort;
        for my $AlwaysColumn (@AlwaysColumns) {
            if ( !grep { $_ eq $AlwaysColumn } @Columns ) {
                push @Columns, $AlwaysColumn;
                $Resort = 1;
            }
        }
        if ($Resort) {
            @Columns = sort { $Self->_DefaultColumnSort() } @Columns;
        }
    }

    {

        # loop through all the dynamic fields to get the ones that should be shown
        DYNAMICFIELDNAME:
        for my $DynamicFieldName (@Columns) {

            next DYNAMICFIELDNAME if $DynamicFieldName !~ m{ DynamicField_ }xms;

            # remove dynamic field prefix
            my $FieldName = $DynamicFieldName;
            $FieldName =~ s/DynamicField_//gi;
            $Self->{DynamicFieldFilter}->{$FieldName} = 1;
        }
    }

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    # get dynamic field backend object
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get filterable Dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsFiltrable = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsFiltrable',
        );

        # if the dynamic field is filterable add it to the ValidFilterableColumns hash
        if ($IsFiltrable) {
            $Self->{ValidFilterableColumns}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = 1;
        }
    }

    # get sortable Dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsSortable = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsSortable',
        );

        # if the dynamic field is sortable add it to the ValidSortableColumns hash
        if ($IsSortable) {
            $Self->{ValidSortableColumns}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = 1;
        }
    }

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

    STRING:
    for my $String (@Params) {
        next STRING if !$String;
        my ( $Key, $Value ) = split /=/, $String;

        if ( $Key eq 'CustomerID' ) {
            $Key = "CustomerIDRaw";
        }

        # push ARRAYREF attributes directly in an ARRAYREF
        if (
            $Key
            =~ /^(StateType|StateTypeIDs|Queues|QueueIDs|Types|TypeIDs|States|StateIDs|Priorities|PriorityIDs|Services|ServiceIDs|SLAs|SLAIDs|Locks|LockIDs|OwnerIDs|ResponsibleIDs|WatchUserIDs|ArchiveFlags|CreatedUserIDs|CreatedTypes|CreatedTypeIDs|CreatedPriorities|CreatedPriorityIDs|CreatedStates|CreatedStateIDs|CreatedQueues|CreatedQueueIDs)$/
            )
        {
            if ( $Value =~ m{,}smx ) {
                push @{ $TicketSearch{$Key} }, split( /,/, $Value );
            }
            else {
                push @{ $TicketSearch{$Key} }, $Value;
            }
        }

        # check if parameter is a dynamic field and capture dynamic field name (with DynamicField_)
        # in $1 and the Operator in $2
        # possible Dynamic Fields options include:
        #   DynamicField_NameX_Equals=123;
        #   DynamicField_NameX_Like=value*;
        #   DynamicField_NameX_GreaterThan=2001-01-01 01:01:01;
        #   DynamicField_NameX_GreaterThanEquals=2001-01-01 01:01:01;
        #   DynamicField_NameX_SmallerThan=2002-02-02 02:02:02;
        #   DynamicField_NameX_SmallerThanEquals=2002-02-02 02:02:02;
        elsif ( $Key =~ m{\A (DynamicField_.+?) _ (.+?) \z}sxm ) {

            # prevent adding ProcessManagement search parameters (for ProcessWidget)
            if ( $Self->{Config}->{IsProcessWidget} ) {
                next STRING if $2 eq $Self->{ProcessManagementProcessID};
                next STRING if $2 eq $Self->{ProcessManagementActivityID};
            }

            push @{ $DynamicFieldsParameters{$1}->{$2} }, $Value;
        }

        elsif ( !defined $TicketSearch{$Key} ) {

            # change sort by, if needed
            if (
                $Key eq 'SortBy'
                && $Self->{SortBy}
                && $Self->{ValidSortableColumns}->{ $Self->{SortBy} }
                )
            {
                $Value = $Self->{SortBy};
            }
            elsif ( $Key eq 'SortBy' && !$Self->{ValidSortableColumns}->{$Value} ) {
                $Value = 'Age';
            }
            $TicketSearch{$Key} = $Value;
        }
        elsif ( !ref $TicketSearch{$Key} ) {
            my $ValueTmp = $TicketSearch{$Key};
            $TicketSearch{$Key} = [$ValueTmp];
            push @{ $TicketSearch{$Key} }, $Value;
        }
        else {
            push @{ $TicketSearch{$Key} }, $Value;
        }
    }
    %TicketSearch = (
        %TicketSearch,
        %DynamicFieldsParameters,
        Permission => $Self->{Config}->{Permission} || 'ro',
        UserID => $Self->{UserID},
    );

    # CustomerInformationCenter shows data per CustomerID
    if ( $Param{CustomerID} ) {
        $TicketSearch{CustomerIDRaw} = $Param{CustomerID};
    }

    # define filter attributes
    my @MyQueues = $QueueObject->GetAllCustomQueues(
        UserID => $Self->{UserID},
    );
    if ( !@MyQueues ) {
        @MyQueues = (999_999);
    }

    # get all queues the agent is allowed to see (for my services)
    my %ViewableQueues = $QueueObject->GetAllQueues(
        UserID => $Self->{UserID},
        Type   => 'ro',
    );
    my @ViewableQueueIDs = sort keys %ViewableQueues;
    if ( !@ViewableQueueIDs ) {
        @ViewableQueueIDs = (999_999);
    }

    # get the custom services from agent preferences
    # set the service ids to an array of non existing service ids (0)
    my @MyServiceIDs = (0);
    if ( $Self->{UseTicketService} ) {
        @MyServiceIDs = $Kernel::OM->Get('Kernel::System::Service')->GetAllCustomServices(
            UserID => $Self->{UserID},
        );

        if ( !defined $MyServiceIDs[0] ) {
            @MyServiceIDs = (0);
        }
    }

    my %TicketSearchSummary = (
        Locked => {
            OwnerIDs => $TicketSearch{OwnerIDs} // [ $Self->{UserID}, ],
            LockIDs => [ '2', '3' ],    # 'lock' and 'tmp_lock'
        },
        Watcher => {
            WatchUserIDs => [ $Self->{UserID}, ],
            LockIDs      => $TicketSearch{LockIDs} // undef,
        },
        Responsible => {
            ResponsibleIDs => $TicketSearch{ResponsibleIDs} // [ $Self->{UserID}, ],
            LockIDs        => $TicketSearch{LockIDs}        // undef,
        },
        MyQueues => {
            QueueIDs => \@MyQueues,
            LockIDs  => $TicketSearch{LockIDs} // undef,
        },
        MyServices => {
            QueueIDs   => \@ViewableQueueIDs,
            ServiceIDs => \@MyServiceIDs,
            LockIDs    => $TicketSearch{LockIDs} // undef,
        },
        All => {
            OwnerIDs => $TicketSearch{OwnerIDs} // undef,
            LockIDs  => $TicketSearch{LockIDs}  // undef,
        },
    );

    if ( defined $TicketSearch{LockIDs} || defined $TicketSearch{Locks} ) {
        delete $TicketSearchSummary{Locked};
    }

    if ( defined $TicketSearch{WatchUserIDs} ) {
        delete $TicketSearchSummary{Watcher};
    }

    if ( defined $TicketSearch{ResponsibleIDs} ) {
        delete $TicketSearchSummary{Responsible};
    }

    if ( defined $TicketSearch{QueueIDs} || defined $TicketSearch{Queues} ) {
        delete $TicketSearchSummary{MyQueues};
        delete $TicketSearchSummary{MyServices}->{QueueIDs};
    }

    if ( !$Self->{UseTicketService} ) {
        delete $TicketSearchSummary{MyServices};
    }

    return (
        Columns             => \@Columns,
        TicketSearch        => \%TicketSearch,
        TicketSearchSummary => \%TicketSearchSummary,
    );
}

sub _DefaultColumnSort {
    my ( $Self, %Param ) = @_;

    my %DefaultColumns = (
        TicketNumber           => 100,
        Age                    => 110,
        Changed                => 111,
        PendingTime            => 112,
        EscalationTime         => 113,
        EscalationSolutionTime => 114,
        EscalationResponseTime => 115,
        EscalationUpdateTime   => 116,
        Title                  => 120,
        State                  => 130,
        Lock                   => 140,
        Queue                  => 150,
        Owner                  => 160,
        Responsible            => 161,
        CustomerID             => 170,
        CustomerName           => 171,
        CustomerUserID         => 172,
        Type                   => 180,
        Service                => 191,
        SLA                    => 192,
        Priority               => 193,
    );

    # set default order of ProcessManagement columns (for process widgets)
    if ( $Self->{Config}->{IsProcessWidget} ) {
        $DefaultColumns{"DynamicField_$Self->{ProcessManagementProcessID}"}  = 101;
        $DefaultColumns{"DynamicField_$Self->{ProcessManagementActivityID}"} = 102;
    }

    # dynamic fields can not be on the DefaultColumns sorting hash
    # when comparing 2 dynamic fields sorting must be alphabetical
    if ( !$DefaultColumns{$a} && !$DefaultColumns{$b} ) {
        return $a cmp $b;
    }

    # when a dynamic field is compared to a ticket attribute it must be higher
    elsif ( !$DefaultColumns{$a} ) {
        return 1;
    }

    # when a ticket attribute is compared to a dynamic field it must be lower
    elsif ( !$DefaultColumns{$b} ) {
        return -1;
    }

    # otherwise do a numerical comparison with the ticket attributes
    return $DefaultColumns{$a} <=> $DefaultColumns{$b};
}

1;

=back
