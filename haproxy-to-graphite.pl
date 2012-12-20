#!/usr/bin/perl
# a perl script to parse haproxy stats page 
# and pipe stats to graphite
#
our ($gport,$ghost,$fename,$statsurl,$hauser,$hstats,$hapass,$haproxy,$hpid,@hapids,$debug,$sock,$stat,$result,$time);
our ($uptime,$numproc,$currconns);


use LWP::UserAgent;
use IO::Socket;
use HTTP::Request;
$stat="test.stat";
$result="1";
$ghost="hmon01";
$gport="8126";
$haproxy="64.235.44.99";
$hahostname="www.houzz.com";
$hstats="sadmin?stats/";
$hauser="alon";
$hapass="tmicha";
$debug="yep";

if ($ARGV[0] ) { $haproxy= $ARGV[0]; }
if ($ARGV[1] ) { $ghost= $ARGV[1]; }
if ($ARGV[2] ) { $gport= $ARGV[2]; }

&getpage;
$debug && print "PID found: $hpid\n";
$debug && print "Uptime: $uptime\n";
&pushgraph("haproxy.$haproxy.haproxy.pid.$hpid.uptime",$uptime); 
$debug && print "number of connections: $currconns\n";
&pushgraph("haproxy.$haproxy.haproxy.pid.$hpid.num_conns",$currconns);
$debug && print "frontend connections: $feconns\n";

exit 0;

sub timestamp{ $time = time; }

sub getpage {
  my $ua = LWP::UserAgent->new or die "no us: $!\n";
  $ua->agent('IcingaProbe/1.01');
  $ua->credentials("$haproxy:80","HAProxy Statistics","$hauser","$hapass");
  my $request = new HTTP::Request('GET',"http://$haproxy/$hstats");
  $request->header('Host',"$hahostname");
  my $response = $ua->request($request);
  my $result = $response->content;
  die "$haproxy error: ",$response->status_line unless $response->is_success;
  &getstats($result);
}

sub getstats{
  my $tmp=shift;
  $tmp =~ s/>/>\n/gi;
  my @tmp=split(/\n/,$tmp); 
  $i= 0;

  for (@tmp) { 
    $h=0 ; # initialize a tmp counter
    $_ =~ s/<.*>$//;
    $_ =~ s/^\s*//;
    # grab the current pid
    if ( $_ =~ /Statistics Report for pid/i ) { 
      $_ =~ s/[^\d]//gi;
      $hpid= $_; 		
      }
    # get the number of processes total
    if ( $_ =~ /nbproc\ =/ ) {
	$_ =~ s/^.*nbproc\ =\ //gi;
	$_ =~ s/[)]//gi;
        $numproc = $_;
	}
     # get the uptime
     if ( $_ =~ /^uptime =/ ) {
 	$h=$i+1;
	$tmpup="$tmp[$h]";
        $tmpup =~ s/<br>$//;
        $tmpup =~ s/\s*//gi;
	my @uptime = split ( /[a-z]/,$tmpup);
        # we're an element short! 0 days?
	if ( $#uptime eq 2 ) { unshift (@uptime,0); } 
	$tmpsec= $tmpsec+($uptime[0]*86400);
	$tmpsec= $tmpsec+($uptime[1]*3600);
	$tmpsec= $tmpsec+($uptime[2]*60);
	$tmpsec= $tmpsec+($uptime[3]);
	$uptime="$tmpsec";
 	}	
  # get the current connections
  if ( $_ =~ /^current conns =/) {
    $_ =~ s/^current conns = //;
    $_ =~ s/;.*$//;
    $currconns=$_;
    }
  # get some frontend stats
  if ( $_ =~ /^Frontend$/ ) {
	  $h=$i+6;
	  $feconns = $tmp[$h];
  	$feconns =~ s/[^\d]*//ig;
  	}
    $i++;
  }
}

sub pushstatd{
  my $statname=shift;
  my $num=shift;
  my $time=time();
  # open a socket to the statsd server
  $sock = IO::Socket::INET->new(
    PeerAddr => $ghost,
    PeerPort => $gport,
    Proto  => 'udp'
    );
  die "Unable to connect to carbon server: $!\n" unless ($sock->connected);
  # send the stats!
  $debug && print "$statname:$num\n";
  $sock->send("$statname:$num\n");
  $sock->shutdown(2) 
 }

sub pushgraph {
  my $statname=shift;
  my $num=shift;
  my $time=time();
  # open a socket to the carbon server
  $sock = IO::Socket::INET->new(
  PeerAddr => $ghost,
  PeerPort => $gport,
  Proto	 => 'tcp'
  );
  die "Unable to connect to carbon server: $!\n" unless ($sock->connected);
  # send the stats!
  $debug && print "$statname $num $time\n";
  $sock->send("$statname $num $time\n"); 
  $sock->shutdown(2)
}
