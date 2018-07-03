use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Path qw(remove_tree make_path);
use File::Spec;

use Migrate::Setup;

my $migrations = File::Spec->catdir('db', 'migrations');
my $config = File::Spec->catfile('db', 'config.pl');
my $config_sample = File::Spec->catfile('db', 'config.pl.example');

subtest 'Migrations path' => sub {
    is(Migrate::Setup::migrations_path, $migrations);
};

subtest 'is_migration_setup reports false if migrations folder is missing' => sub {
    make_db();
    create_files();

    ok(!Migrate::Setup::is_migration_setup);
};

subtest 'is_migration_setup reports false if config file is missing' => sub {
    make_migrations();
    create_config_sample();

    ok(!Migrate::Setup::is_migration_setup);
};

subtest 'is_migration_setup reports false if sample config file is missing' => sub {
    make_migrations();
    create_config();

    ok(!Migrate::Setup::is_migration_setup);
};

subtest 'is_migration_setup reports true if migrations are setup' => sub {
    make_migrations();
    create_files();

    ok(Migrate::Setup::is_migration_setup, 'Should report migration folder does not exist');
};

subtest 'create_migrations_folder creates the migrations folder' => sub {
    remove_root();
    ok(!-e $migrations, 'Precondition: migration should not exist');

    Migrate::Setup::create_migrations_folder();

    ok(-e $migrations, 'Migrations folder should have been created');
};

subtest 'create_migration_config_sample_file copies configuration sample file from templates' => sub {
    remove_root();

    Migrate::Setup::create_migration_config_sample_file();

    ok(-e $config_sample, 'Migrations sample config copied');
};

subtest 'create_migration_config_sample_file returns 1 if the file did not already exist' => sub {
    remove_root();

    my $res = Migrate::Setup::create_migration_config_sample_file();

    ok($res, 'Returns true');
};

subtest 'create_migration_config_sample_file returns 0 if the file already exists' => sub {
    make_migrations();
    create_config_sample();

    my $res = Migrate::Setup::create_migration_config_sample_file();

    ok(!$res, 'Returns false');
};

subtest 'create_migration_config_file when sample does not exists copies config from templates' => sub {
    remove_root();

    Migrate::Setup::create_migration_config_file();

    ok(-e $config, 'Migrations config template copied');
    like(file_contents($config), qr/dsn =>.*schema =>/s);
};

subtest 'create_migration_config_file when sample exists copies config from sample' => sub {
    make_db();
    create_config_sample('ANY CONTENT');

    Migrate::Setup::create_migration_config_file();

    ok(-e $config, 'Migrations config template copied');
    is(file_contents($config), 'ANY CONTENT');
};

subtest 'create_migration_config_file returns true if the file did not already exist' => sub {
    remove_root();

    my $res = Migrate::Setup::create_migration_config_sample_file();

    ok($res, 'Returns true');
};

subtest 'create_migration_config_file returns false if the file already exists' => sub {
    make_db();
    create_config();

    my $res = Migrate::Setup::create_migration_config_file();

    ok(!$res, 'Returns false');
};

subtest 'setup creates all necessary migration files and folder' => sub {
    remove_root();

    Migrate::Setup::setup();

    ok(-e $config, 'Migrations config template copied');
    ok(-e $config_sample, 'Migrations config sample template copied');
    ok(-e $migrations, 'Migrations config sample template copied');
};

subtest 'setup returns a list of created items or errors found' => sub {
    make_db();
    create_config_sample(); # Exists so don't list

    my $module = new Test::MockModule('Migrate::Setup');
    $module->mock(create_migration_config_file => sub { die("File error!!!\n") });

    my @res = Migrate::Setup::setup();

    ok(!-e $config, 'Migrations config template copied');
    ok(-e $migrations, 'Migrations config sample template copied');
    is_deeply(\@res, [$migrations, "Could not create file:$config File error!!!"]);
};

subtest 'setup returns an empty list if already setup' => sub {
    remove_root();
    Migrate::Setup::setup();

    my @res = Migrate::Setup::setup();

    is(scalar @res, 0, 'Result is empty');
};

sub make_db { remove_root(); make_path('db') }
sub make_migrations { remove_root(); make_path($migrations) }
sub remove_root { remove_tree('db') }
sub create_config { my $content = shift; create_file($config, $content) }
sub create_config_sample { my $content = shift; create_file($config_sample, $content) }
sub create_files { create_config(); create_config_sample() }

sub file_contents {
    my $file = shift;
    open my $fh, '<', $file or die($!);
    $/ = undef;
    my $ret = <$fh>;
    close $fh;
    return $ret;
}

sub create_file {
    my $file = shift;
    my $content = shift;
    open my $fh, '>', $file or die($!);
    print $fh $content if $content;
    close $fh;
}

sub assert_creates_migrations {
    my $dbh = shift;
    my @sql = @_;
    my $run = 0;

    foreach my $s (@sql) {
        is($dbh->call_pos(++$run), 'do', "Run #$run: Should run do for the first SQL statement");
        is($dbh->call_args_pos($run, 1), $dbh, "Run #$run: Should be called as object");
        is($dbh->call_args_pos($run, 2), $sql[$run - 1], "Run #$run: Should run '${s}'");
    }
    $dbh->clear();
}

done_testing;