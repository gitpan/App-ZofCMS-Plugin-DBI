package App::ZofCMS::Plugin::DBI;

use warnings;
use strict;

our $VERSION = '0.0101';

use strict;
use warnings;
use DBI;
use Carp;

sub new { bless {}, shift; }

sub process {
    my ( $self, $template, $query, $config ) = @_;
    
    my $dbi_conf = {
        %{ $config->conf->{dbi} || {} },
        %{ delete $template->{dbi} || {} },
    };
    
    $dbi_conf or return;

    ( $dbi_conf->{dbi_set} or $dbi_conf->{dbi_get} )
        or return;
    my $dbh = DBI->connect_cached(
        @$dbi_conf{ qw/dsn user pass opt/ }
    );
    
    if ( $dbi_conf->{dbi_set} ) {
        if ( ref $dbi_conf->{dbi_set} eq 'CODE'
            or not ref $dbi_conf->{dbi_set}[0]
        ) {
            $dbi_conf->{dbi_set} = [ $dbi_conf->{dbi_set} ];
        }
        
        for my $set ( @{ $dbi_conf->{dbi_set} } ) {
            if ( ref $set eq 'CODE' ) {
                my $sub_set_ref = $set->($query, $template, $config, $dbh );

                $sub_set_ref = [ $sub_set_ref ]
                    unless not $sub_set_ref
                        or ( ref $sub_set_ref eq 'ARRAY'
                            and ref $sub_set_ref->[0] eq 'ARRAY'
                        );
                $dbh->do( @$_ ) for @{ $sub_set_ref || [] };
            }
            else {
                $dbh->do( @$set );
            }
        }
    }
    
    if ( $dbi_conf->{dbi_get} ) {
        if ( ref $dbi_conf->{dbi_get} eq 'HASH' ) {
            $dbi_conf->{dbi_get} = [ $dbi_conf->{dbi_get} ];
        }

        for my $get ( @{ $dbi_conf->{dbi_get} } ) {
            $get->{type}   ||= 'loop';
            $get->{name}   ||= 'dbi_var';
            $get->{method} ||= 'selectall';
            $get->{cell}   ||= 't';

            if ( $get->{type} eq 'loop' ) {
                my $data_ref;
                if ( $get->{method} eq 'selectall' ) {
                    $data_ref = $dbh->selectall_arrayref(
                        @{ $get->{sql} },
                    );
                    $template->{ $get->{cell} }{ $get->{name} } = $self->_prepare_loop(
                        $data_ref,
                        $get->{layout},
                    );
                }
            }
        }
    }
}

sub _prepare_loop {
    my ( $self, $data_ref, $layout_ref ) = @_;
    
    my @loop;
    for my $entry_ref ( @$data_ref ) {
        push @loop, {
            map +(
                $layout_ref->[$_] => $entry_ref->[$_]
            ), 0 .. $#$entry_ref
        };
    }
    
    return \@loop;
}


1;
__END__

=head1 NAME

App::ZofCMS::Plugin::DBI - DBI access from ZofCMS templates

=head1 SYNOPSIS

In your main config file or ZofCMS template:

    dbi => {
        dsn     => "DBI:mysql:database=test;host=localhost",
        user    => 'test', # user,
        pass    => 'test', # pass
        opt     => { RaiseError => 1, AutoCommit => 0 },
    },

In your ZofCMS template:

    dbi => {
        dbi_get => {
            layout  => [ qw/name pass/ ],
            sql     => [ 'SELECT * FROM test' ],
        },
        dbi_set => sub {
            my $query = shift;
            if ( defined $query->{user} and defined $query->{pass} ) {
                return [
                    [ 'DELETE FROM test WHERE name = ?;', undef, $query->{user}      ],
                    [ 'INSERT INTO test VALUES(?,?);', undef, @$query{qw/user pass/} ],
                ];
            }
            elsif ( defined $query->{delete} and defined $query->{user_to_delete} ) {
                return [ 'DELETE FROM test WHERE name =?;', undef, $query->{user_to_delete} ];
            }
            return;
        },
    },

In your L<HTML::Template> template:

    <form action="" method="POST">
        <div>
            <label for="name">Name: </label>
            <input id="name" type="text" name="user" value="<tmpl_var name="query_user">"><br>
            <label for="pass">Pass: </label>
            <input id="pass" type="text" name="pass" value="<tmpl_var name="query_pass">"><br>
            <input type="submit" value="Add">
        </div>
    </form>
    
    <table>
        <tmpl_loop name="dbi_var">
            <tr>
                <td><tmpl_var name="name"></td>
                <td><tmpl_var name="pass"></td>
                <td>
                    <form action="" method="POST">
                        <div>
                            <input type="hidden" name="user_to_delete" value="<tmpl_var name="name">">
                            <input type="submit" name="delete" value="Delete">
                        </div>
                    </form>
                </td>
            </tr>
        </tmpl_loop>
    </table>

=head1 DESCRIPTION

Module is a L<App::ZofCMS> plugin which provides means to retrieve
and push data to/from SQL databases using L<DBI> module.

Current functionality is limited. More will be added as the need arrises,
let me know if you need something extra.

This documentation assumes you've read L<App::ZofCMS>,
L<App::ZofCMS::Config> and L<App::ZofCMS::Template>

=head1 DSN AND CREDENTIALS

    dbi => {
        dsn     => "DBI:mysql:database=test;host=localhost",
        user    => 'test', # user,
        pass    => 'test', # pass
        opt     => { RaiseError => 1, AutoCommit => 0 },
    },

You can set these either in your ZofCMS template's C<dbi> key or in your
main config file's C<dbi> key. The key takes a hashref as a value.
The keys/values of that hashref are as follows:

=head2 C<dsn>

    dsn => "DBI:mysql:database=test;host=localhost",

Specifies the DSN for DBI, see C<DBI> for more information on what to use
here.

=head2 C<user> and C<pass>

        user    => 'test', # user,
        pass    => 'test', # pass

The C<user> and C<pass> key should contain username and password for
the database you will be accessing with your plugin.

=head2 C<opt>

    opt => { RaiseError => 1, AutoCommit => 0 },

The C<opt> key takes a hashref of any additional options you want to
pass to C<connect_cached> L<DBI>'s method.

=head1 RETRIEVING FROM AND SETTING DATA IN THE DATABASE

In your ZofCMS template the first-level C<dbi> key accepts a hashref two
possible keys: C<dbi_get> for retreiving data from database and C<dbi_set>
for setting data into the database. Note: you can also have your C<dsn>,
C<user>, C<pass> and C<opt> keys here if you wish.

=head2 C<dbi_get>

    dbi => {
        dbi_get => {
            layout  => [ qw/name pass/ ],
            sql     => [ 'SELECT * FROM test' ],
        },
    }

    dbi => {
        dbi_get => [
            {
                layout  => [ qw/name pass/ ],
                sql     => [ 'SELECT * FROM test' ],
            },
            {
                layout  => [ qw/name pass time info/ ],
                sql     => [ 'SELECT * FROM bar' ],
            },
        ],
    }

The C<dbi_get> key takes either a hashref or an arrayref as a value.
If the value is a hashref it is the same as having just that hashref
inside the arrayref. Each element of the arrayref must be a hashref with
instructions on how to retrieve the data. The possible keys/values of
that hashref are as follows:

=head3 C<layout>

    layout  => [ qw/name pass time info/ ],

B<Mandatory>. Takes an arrayref as an argument.
Specifies the name of C<< <tmpl_var name=""> >>s in your
C<< <tmpl_loop> >> (see C<type> argument below) to which map the columns
retrieved from the database, see C<SYNOPSIS> section above.

=head3 C<sql>

    sql => [ 'SELECT * FROM bar' ],

B<Mandatory>. Takes an arrayref as an argument which will be directly
dereferenced into the L<DBI>'s method call specified by C<method> argument
(see below). See L<App::ZofCMS::Plugin::Tagged> for possible expansion
of possibilities you have here.

=head3 C<type>

    dbi_get => {
        type    => 'loop'
    ...

B<Optional>. Specifies what kind of a L<HTML::Template> variable to
generate from database data. Currently the only supported value is C<loop>
which generates C<< <tmpl_loop> >> for yor L<HTML::Template> template.
B<Defaults to:> C<loop>

=head3 C<name>

    dbi_get => {
        name    => 'the_var_name',
    ...

B<Optional>. Specifies the name of the key in the C<cell> (see below) into
which to stuff your data. With the default C<cell> argument this will
be the name of a L<HTML::Template> var to set. B<Defaults to:> C<dbi_var>

=head3 C<method>

    dbi_get => {
        method => 'selectall',
    ...

B<Optional>. Specifies with which L<DBI> method to retrieve the data.
Currently the only supported value for this key is C<selectall> which
uses L<selectall_arrayref>. B<Defaults to:> C<selectall>

=head3 C<cell>

    dbi_get => {
        cell => 't'
    ...

B<Optional>. Specifies the ZofCMS template's first-level key in which to
create the C<name> key with data from the database. C<cell> must point
to a key with a hashref in it (though, keep autovivification in mind).
Possibly the sane values for this are either C<t> or C<d>. B<Defaults to:>
C<t> (the data will be available in your L<HTML::Template> templates)

=head2 C<dbi_set>

    dbi_set => sub {
        my $query = shift;
        if ( defined $query->{user} and defined $query->{pass} ) {
            return [
                [ 'DELETE FROM test WHERE name = ?;', undef, $query->{user}      ],
                [ 'INSERT INTO test VALUES(?,?);', undef, @$query{qw/user pass/} ],
            ];
        }
        elsif ( defined $query->{delete} and defined $query->{user_to_delete} ) {
            return [ 'DELETE FROM test WHERE name =?;', undef, $query->{user_to_delete} ];
        }
        return;
    },

    dbi_set => [
        'DELETE FROM test WHERE name = ?;', undef, 'foos'
    ],

    dbi_set => [
        [ 'DELETE FROM test WHERE name = ?;', undef, 'foos' ],
        [ 'INSERT INTO test VALUES(?, ?);', undef, 'foos', 'bars' ],
    ]

B<Note:> the C<dbi_set> will be processed B<before> C<dbi_get>. Takes
either a subref or an arrayref as an argument. Multiple instructions
can be put inside an arrayref as the last example above demonstrates. Each
arrayref will be directly dereferenced into L<DBI>'s C<do()> method. Each
subref must return either a single scalar, an arrayref or an arrayref
of arrayrefs. Returning a scalar is the same as returning an arrayref
with just that scalar in it. Returning just an arrayref is the same as
returning an arrayref with just that arrayref in it. Each arrayref of
the resulting arrayref will be directly dereferenced into L<DBI>'s C<do()>
method. The subrefs will have the following in their C<@_> when called:
C<< $query, $template, $config, $dbh >>. Where C<$query> is a hashref
of query parameters in which keys are the name of the parameters and
values are values. C<$template> is a hashref of your ZofCMS template.
C<$config> is the L<App::ZofCMS::Config> object and C<$dbh> is L<DBI>'s
database handle object.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-zofcms-plugin-dbi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-ZofCMS-Plugin-DBI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::ZofCMS::Plugin::DBI

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-ZofCMS-Plugin-DBI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-ZofCMS-Plugin-DBI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-ZofCMS-Plugin-DBI>

=item * Search CPAN

L<http://search.cpan.org/dist/App-ZofCMS-Plugin-DBI>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

