#!/usr/bin/perl
#this script can be used for reconfigure for slurm
#slurm default installation path:
#/usr/local
#/usr/local/etc
use warnings;
use strict;
use Expect;
use Parallel::ForkManager;
use MCE::Shared;

`systemctl stop slurmctld.service`;# stop working slurmctld first
my $expectT = 30;# time peroid for expect

open my $ss,"< ./Nodes_IP.dat" or die "No Nodes_IP.dat to read"; 
my @temp_array=<$ss>;
my @avaIP=grep (($_!~m{^\s*$|^#}),@temp_array); # remove blank lines and comment lines
chomp @avaIP;
close $ss;
 
for (@avaIP){
	$_  =~ s/^\s+|\s+$//;
	chomp;
	#print "IP: $_\n";
}

my $forkNo = @avaIP;
my $pm = Parallel::ForkManager->new("$forkNo");

my @partition = (
'PartitionName=debug Nodes=node[01-02] Default=YES MaxTime=INFINITE State=UP',
#'PartitionName=TotalCore24 Nodes=node[21] Default=YES MaxTime=INFINITE State=UP',
#'PartitionName=AMD Nodes=node02 Default=NO MaxTime=INFINITE State=UP'
);

open my $ss1,"<./IP_coreNo.txt" or die "No IP_coreNo.txt to read";
my @temp_array1=<$ss1>;
my @input= grep (($_!~m{^\s*$|^#}),@temp_array1); # remove blank lines and comment lines
close($ss1);
for (@input){
	$_  =~ s/^\s+|\s+$//;
	chomp;	
}

my %coreNo;
my %socketNo;
my %threadcoreNo;
my %coresocketNo;

for (1..$#input){#the first line shows the headers,skip it.
	$input[$_] =~s/^\s+//g;#replace operation 
	my @temp = split(/\s+/,$input[$_]);
	chomp $temp[0];
	chomp $temp[1];
	chomp $temp[2];
	chomp $temp[3];
	chomp $temp[4];
	$coreNo{$temp[0]}=$temp[1];
	$socketNo{$temp[0]}=$temp[2];
	$threadcoreNo{$temp[0]}=$temp[3];
	$coresocketNo{$temp[0]}=$temp[4];
	print " IP and CoreNo: $temp[0]  $coreNo{$temp[0]} \n";
	print " IP and SocketNo: $temp[0]  $socketNo{$temp[0]} \n";
	print " IP and Thread perl Core: $temp[0]  $threadcoreNo{$temp[0]} \n";
	print " IP and Core perl Socket: $temp[0]  $coresocketNo{$temp[0]} \n";
}

$ENV{TERM} = "vt100";
my $pass = "123"; ##For all roots of nodes

#### end of debug
# COMPUTE NODES
unlink "./slurm.conf";
system("cp slurmConf_template.txt slurm.conf");# cp from template file

for (@avaIP){
#	print "Keys: $_\n";
    $_ =~/192.168.0.(\d{1,3})/;
	my $nodeID = $1 - 1;# node ID according to th fourth number of current IP
	chomp($nodeID);
    my $formatted_nodeID = sprintf("%02d",$nodeID);
    my $Nodename="node"."$formatted_nodeID";
   `echo "NodeName=$Nodename NodeAddr=$_ CPUs=$coreNo{$_} Sockets=$socketNo{$_} ThreadsPerCore=$threadcoreNo{$_} CoresPerSocket=$coresocketNo{$_}  State=UNKNOWN" >> ./slurm.conf`;#append the data into the file
#Sockets=1 CoresPerSocket=12 ThreadsPerCore=2
}

for (@partition){`echo "$_" >> ./slurm.conf`;}

unlink "/etc/slurm/slurm.conf";
`cp ./slurm.conf /usr/local/etc/`;

# The follwoing is for slurm setting
for (@avaIP){	
#for (sort keys %coreNo){
    $pm->start and next;    
    $_ =~/192.168.0.(\d{1,3})/;
	my $nodeID = $1 - 1;# node ID according to th fourth number of current IP
	chomp($nodeID);
    my $formatted_nodeID = sprintf("%02d",$nodeID);
    my $nodename="node"."$formatted_nodeID";
    print "**Slurm setting for $nodename: scp slurm.conf\n";
	chomp($nodename);
	system("ssh $nodename \" systemctl stop slurmd\" ");    
	my $exp = Expect->new;
	$exp = Expect->spawn("scp  /usr/local/etc/slurm.conf root\@$nodename:/usr/local/etc/ \n");	
    $exp->soft_close();
    #sleep(1);
	$pm->finish;
}# for loop
$pm->wait_all_children;
print "SCP done\n";
#sleep(100);
### Server setting for Server
`chown -R slurm:root /var/spool`;
`chown -R slurm:root /var/run`;
system("rm -f /var/log/slurmctld.log");
`touch /var/log/slurmctld.log`;
`chown slurm:root /var/log/slurmctld.log`;
system("rm -f /var/log/slurm_jobacct.log");
system("rm -f /var/log/slurm_jobcomp.log");

`touch /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log`;
`chown slurm:root /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log`;
system("firewall-cmd --zone=internal --add-port={6817/tcp,6818/udp} --permanent");
system(" firewall-cmd --reload");
sleep(1);
`systemctl enable slurmctld.service`;
`systemctl start slurmctld.service`;
#`systemctl status slurmctld.service`;

sleep(1);
######## start and enable slurm  for each node
for (sort keys %coreNo){
	$pm->start and next;
    $_ =~/192.168.0.(\d{1,3})/;
	my $nodeID = $1 - 1;# node ID according to th fourth number of current IP
	chomp($nodeID);
    my $formatted_nodeID = sprintf("%02d",$nodeID);
    my $Nodename="node"."$formatted_nodeID";
	my $exp = Expect->new;
	$exp = Expect->spawn("ssh $Nodename \n");
	$exp -> send("rm -rf /var/spool/slurmd \n") if ($exp->expect($expectT,'#'));
	$exp -> send("mkdir /var/spool/slurmd \n") if ($exp->expect($expectT,'#'));
	$exp -> send("chown slurm:root /var/spool/slurmd \n") if ($exp->expect($expectT,'#'));
	$exp -> send("chmod 755 /var/spool/slurmd \n") if ($exp->expect($expectT,'#'));
	$exp -> send("rm -rf /var/log/slurmd.log \n") if ($exp->expect($expectT,'#'));
	$exp -> send("touch /var/log/slurmd.log \n") if ($exp->expect($expectT,'#'));
	$exp -> send("rm -rf /var/log/slurmd.pid \n") if ($exp->expect($expectT,'#'));
	$exp -> send("touch /var/log/slurmd.pid \n") if ($exp->expect($expectT,'#'));
	$exp -> send("chown slurm:root /var/log/slurmd.log \n") if ($exp->expect($expectT,'#'));
	$exp -> send("chown slurm:root /var/run/slurmd.pid \n") if ($exp->expect($expectT,'#'));
	$exp -> send("systemctl stop firewalld\n") if ($exp->expect($expectT,'#'));
	$exp -> send("systemctl disable firewalld\n") if ($exp->expect($expectT,'#'));
	$exp -> send("slurmd -C \n") if ($exp->expect($expectT,'#'));
	$exp -> send("systemctl enable slurmd.service \n") if ($exp->expect($expectT,'#'));
	$exp -> send("systemctl stop slurmd.service \n") if ($exp->expect($expectT,'#'));
	$exp -> send("systemctl start slurmd.service \n") if ($exp->expect($expectT,'#'));
	#$exp -> send("systemctl status slurmd.service \n") if ($exp->expect($expectT,'#'));
	$exp -> send(" \n") if ($exp->expect($expectT,'2'));
	$exp -> send("exit\n") if ($exp->expect($expectT,'#'));
	$exp->soft_close();
	$pm->finish;
} # end of loop
$pm->wait_all_children;
### start slurm for server


print "***** WATCH OUT!!!!!\n";
print "***** Begin slurmd check node by node!!!!!\n\n";
sleep(3);

for (@avaIP){	
    $_ =~/192.168.0.(\d{1,3})/;
	my $nodeID = $1 - 1;# node ID according to th fourth number of current IP
	chomp($nodeID);
    my $formatted_nodeID = sprintf("%02d",$nodeID);
    my $nodename="node"."$formatted_nodeID";
    my $exp = Expect->new;
	$exp = Expect->spawn("ssh $nodename \n");
	$exp -> send("slurmd -C \n") if ($exp->expect($expectT,'#'));	
	$exp -> send("exit\n") if ($exp->expect($expectT,'#'));
	$exp->soft_close();
	print "\n"; 
	sleep(3);
}# for loop

#To display the compute nodes: scontrol show nodes
#To display the job queue: scontrol show jobs
#To submit script jobs: sbatch -N2 script-file
