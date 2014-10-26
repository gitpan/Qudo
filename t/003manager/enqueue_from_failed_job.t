use strict;
use warnings;
use Qudo::Test;
use Test::More;
use Test::Output;

run_tests(10, sub {
    my $driver = shift;
    my $master = test_master(
        driver_class => $driver,
    );

    my $manager = $master->manager;
    $manager->can_do('Worker::Test');
    my $job = $manager->enqueue("Worker::Test", { arg => 'arg', uniqkey => 'uniqkey'});

    is $job->id, 1;
    is $job->arg, 'arg';
    is $job->uniqkey, 'uniqkey';

    $manager->work_once; # worker failed.

    my $exception = $master->exception_list;
    is $master->exception_list->[0]->{retried}, 0;
    $job = $manager->enqueue_from_failed_job($exception->[0]);

    is $job->id, 2;
    is $job->arg, 'arg';
    is $job->uniqkey, 'uniqkey';

    $exception = $master->exception_list;
    is $master->exception_list->[0]->{retried}, 1;

    stderr_like( sub {$manager->enqueue_from_failed_job($exception->[0])}, qr/this exception is already retried/);

    is $master->job_count([qw/Worker::Test/]), 1;

    teardown_db;
});

package Worker::Test;
use base 'Qudo::Worker';

sub grab_for { 0 }
sub work {
    die 'failed';
}
