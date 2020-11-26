#!/usr/bin/perl
=b
05munge_slave.pl is conducted by 07munge_server.pl in Server folder

=cut
use strict;
use warnings;

my @node_array = ("00interfaces_slave.pl","01packages_slave.pl"
			   ,"02hosts_slave.pl","03NFS_slave.pl"
			   ,"04NIS_slave.pl");
for (@node_array){
	system("perl $_");
	sleep(1);
}

`ip a` =~ m{192.168.0.(\d{1,3})\/24};
my $nodeID = $1 - 1;# node ID according to th fourth number of current IP
my $formatted_nodeID = sprintf("%02d",$nodeID);
my $hostname="node"."$formatted_nodeID";
print "hostname $hostname\n";
unlink "/home/$hostname".".txt"; 
open my $Check, "> /home/$hostname".".txt"; #You may check the NFS workable or not at the same time
print $Check "****NFS test\n";
my $temp = `df -hT`;
print $Check "$temp\n";
print $Check "\n\n *** If you see master:/home and master:/opt, NFS works for this slave node.\n";
print $Check "========****End of NFS test\n\n";

print $Check "\n\n===============================\n";
print $Check "****NIS test\n";
print $Check "===yptest:\n";
my $temp1 = `yptest`;
print $Check "$temp1\n";
print  $Check "\n\nIf you see the 9 test results, the nis setting is ok\n";
print $Check "===ypwhich:\n";
my $temp2 = `ypwhich`;
print $Check "$temp2\n";
print  $Check "\n\nIf you see the 9 test results, the nis setting is ok\n";
print  $Check "========****End of NIS test\n\n";
print $Check "\n\n***** date check******\n";
my $temp3 = `date`;
print $Check "****date check: $temp3\n";
close($Check);