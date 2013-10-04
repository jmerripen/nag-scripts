#!/usr/bin/perl
#  automatically watch for updates to the current branch, and push them 
#  using the update-working.pl script to your working directory 
#  copy the script to the directory containing your repo: cp $0 ../ 
#  and run it from there.
#  this could go horribly wrong :)
#  but if you're brave run like so: # nohup $0 <reponame> <updatescript>&

use Cwd;
use IO::Socket;

$ARGV[0] || die "usage: $0 <git repo directory>\n";
chomp $ARGV[0];
our $repo = ( split '/', $ARGV[0])[-1];
our $dir = $ARGV[0];
our $git="/usr/bin/git";
our $gitwho="--format=%cn";
our $gitwhen="--format=%ct";
our $gitsub="--format=%s";
our $gport="2003";
our $ghost="hmon01";
our $graphpath="test.$project.commit";
print "reading log of git repo $repo in directory $dir\n";
chdir "$dir" || die "cannot read repo $repo : $!\n";
&getcommits;
exit 0;

sub getcommits {
my @list=`git log --no-merges --oneline |cut -f1 -d " " |xargs git rev-parse`;
foreach $commit (@list)  {
  chomp $commit;
  &checkcommit("$commit");
  }

}
sub checkcommit {
    my $com=shift;
    chomp ( my $cwho=`$git log $com -1 $gitwho` );
    chomp ( my $cwhen=`$git log $com -1 $gitwhen` );
    chomp ( my $csub=`$git log $com -1 $gitsub` );
    print "$com :[$cwhen] $cwho : $csub\n";
    # &pushgraph("$graphpath.commit.$com","1");
}

sub timestamp{ chomp ( $time=`date`) ; }

sub pushgraph {
  my $statname=shift;
  my $num=shift;
  my $utime=time();
  # open a socket to the carbon server
  $sock = IO::Socket::INET->new(
  PeerAddr => $ghost,
  PeerPort => $gport,
  Proto  => 'tcp'
  );
  die "Unable to connect to carbon server: $!\n" unless ($sock->connected);
  # send the stats!
  $sock->send("$statname $num $utime\n");
  $sock->shutdown(2)
}
