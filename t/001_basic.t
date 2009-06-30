#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 33;
use Test::Exception;

{
    package Roles::Blah;
    use Moose::Role;
    use MooseX::Params::Validate;

    requires 'bar';
    requires 'baz';

    sub foo {
        my ( $self, %params ) = validated_hash(
            \@_,
            bar => { isa => 'Str', default => 'Moose' },
        );
        return "Horray for $params{bar}!";
    }

    package Foo;
    use Moose;
    use Moose::Util::TypeConstraints;
    use MooseX::Params::Validate;

    with 'Roles::Blah';

    sub bar {
        my $self   = shift;
        my %params = validated_hash(
            \@_,
            foo   => { isa => 'Foo' },
            baz   => { isa => 'ArrayRef | HashRef', optional => 1 },
            gorch => { isa => 'ArrayRef[Int]', optional => 1 },
        );
        [ $params{foo}, $params{baz}, $params{gorch} ];
    }

    sub baz {
        my $self   = shift;
        my %params = validated_hash(
            \@_,
            foo => {
                isa => subtype( 'Object' => where { $_->isa('Foo') } ),
                optional => 1
            },
            bar => { does => 'Roles::Blah', optional => 1 },
            boo => {
                does     => role_type('Roles::Blah'),
                optional => 1
            },
        );
        return $params{foo} || $params{bar} || $params{boo};
    }
}

my $foo = Foo->new;
isa_ok( $foo, 'Foo' );

is( $foo->foo, 'Horray for Moose!', '... got the right return value' );
is( $foo->foo( bar => 'Rolsky' ), 'Horray for Rolsky!',
    '... got the right return value' );

is( $foo->baz( foo => $foo ), $foo, '... foo param must be a Foo instance' );

throws_ok { $foo->baz( foo => 10 ) } qr/\QThe 'foo' parameter ("10")/,
    '... the foo param in &baz must be a Foo instance';
throws_ok { $foo->baz( foo => "foo" ) } qr/\QThe 'foo' parameter ("foo")/,
    '... the foo param in &baz must be a Foo instance';
throws_ok { $foo->baz( foo => [] ) } qr/\QThe 'foo' parameter/,
    '... the foo param in &baz must be a Foo instance';

is( $foo->baz( bar => $foo ), $foo, '... bar param must do Roles::Blah' );

throws_ok { $foo->baz( bar => 10 ) } qr/\QThe 'bar' parameter ("10")/,
'... the bar param in &baz must be do Roles::Blah';
throws_ok { $foo->baz( bar => "foo" ) } qr/\QThe 'bar' parameter ("foo")/,
'... the bar param in &baz must be do Roles::Blah';
throws_ok { $foo->baz( bar => [] ) } qr/\QThe 'bar' parameter/,
'... the bar param in &baz must be do Roles::Blah';

is( $foo->baz( boo => $foo ), $foo, '... boo param must do Roles::Blah' );

throws_ok { $foo->baz( boo => 10 ) } qr/\QThe 'boo' parameter ("10")/,
'... the boo param in &baz must be do Roles::Blah';
throws_ok { $foo->baz( boo => "foo" ) } qr/\QThe 'boo' parameter ("foo")/,
'... the boo param in &baz must be do Roles::Blah';
throws_ok { $foo->baz( boo => [] ) } qr/\QThe 'boo' parameter/,
'... the boo param in &baz must be do Roles::Blah';

throws_ok { $foo->bar } qr/\QMandatory parameter 'foo'/,
    '... bar has a required param';
throws_ok { $foo->bar( foo => 10 ) } qr/\QThe 'foo' parameter ("10")/,
    '... the foo param in &bar must be a Foo instance';
throws_ok { $foo->bar( foo => "foo" ) } qr/\QThe 'foo' parameter ("foo")/,
    '... the foo param in &bar must be a Foo instance';
throws_ok { $foo->bar( foo => [] ) } qr/\QThe 'foo' parameter/,
    '... the foo param in &bar must be a Foo instance';
throws_ok { $foo->bar( baz => [] ) } qr/\QMandatory parameter 'foo'/,,
    '... bar has a required foo param';

is_deeply(
    $foo->bar( foo => $foo ),
    [ $foo, undef, undef ],
    '... the foo param in &bar got a Foo instance'
);

is_deeply(
    $foo->bar( foo => $foo, baz => [] ),
    [ $foo, [], undef ],
    '... the foo param and baz param in &bar got a correct args'
);

is_deeply(
    $foo->bar( foo => $foo, baz => {} ),
    [ $foo, {}, undef ],
    '... the foo param and baz param in &bar got a correct args'
);

throws_ok { $foo->bar( foo => $foo, baz => undef ) }
qr/\QThe 'baz' parameter (undef)/,
    '... baz requires a ArrayRef | HashRef';
throws_ok { $foo->bar( foo => $foo, baz => 10 ) }
qr/\QThe 'baz' parameter ("10")/,
    '... baz requires a ArrayRef | HashRef';
throws_ok { $foo->bar( foo => $foo, baz => 'Foo' ) }
qr/\QThe 'baz' parameter ("Foo")/,
    '... baz requires a ArrayRef | HashRef';
throws_ok { $foo->bar( foo => $foo, baz => \( my $var ) ) }
qr/\QThe 'baz' parameter/,
    '... baz requires a ArrayRef | HashRef';

is_deeply(
    $foo->bar( foo => $foo, gorch => [ 1, 2, 3 ] ),
    [ $foo, undef, [ 1, 2, 3 ] ],
    '... the foo param in &bar got a Foo instance'
);

throws_ok { $foo->bar( foo => $foo, gorch => undef ) }
qr/\QThe 'gorch' parameter (undef)/,
    '... gorch requires a ArrayRef[Int]';
throws_ok { $foo->bar( foo => $foo, gorch => 10 ) }
qr/\QThe 'gorch' parameter ("10")/,
    '... gorch requires a ArrayRef[Int]';
throws_ok { $foo->bar( foo => $foo, gorch => 'Foo' ) }
qr/\QThe 'gorch' parameter ("Foo")/,
    '... gorch requires a ArrayRef[Int]';
throws_ok { $foo->bar( foo => $foo, gorch => \( my $var ) ) }
qr/\QThe 'gorch' parameter/,
    '... gorch requires a ArrayRef[Int]';
throws_ok { $foo->bar( foo => $foo, gorch => [qw/one two three/] ) }
qr/\QThe 'gorch' parameter/,
    '... gorch requires a ArrayRef[Int]';

