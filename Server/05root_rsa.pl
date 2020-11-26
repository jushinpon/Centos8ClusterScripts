=b
This script helps to build the passwordless ssh longin to each node by root account. Developed by Prof. Shin-Pon Ju at NSYSY
2019/12/30

Nodes_IP.dat shows all node IPs (from 00initial_interfacesSetting.pl). you
may set new IPs for newly installed nodes. 
=cut
use strict;
use warnings;

use Expect;  
use Parallel::ForkManager;
use MCE::Shared;
my $expectT = 20;# time peroid for expect

$ENV{TERM} = "vt100";
my $pass = "123"; ##For all roots of nodes

open my $ss,"< ./Nodes_IP.dat" or die "No Nodes_IP.dat to read"; 
my @temp_array=<$ss>;
my @avaIP=grep (($_!~m{^\s*$|^#}),@temp_array); # remove blank lines and comment lines
close $ss; 

for (@avaIP){
	$_  =~ s/^\s+|\s+$//;
	chomp;
	print "IP: $_\n";
}
my $forkNo = @avaIP;
print "forkNo: $forkNo\n";

system("rm -f /root/\.ssh/*");# remove unexpect thing first
system("mkdir /root/\.ssh/*");
chdir("/root/.ssh");
system("ssh-keygen -t rsa -N \"\" -f id_rsa");
system("cp id_rsa.pub authorized_keys");
system("chmod 700 /root/\.ssh");
system("chmod 640 /root/\.ssh/authorized_keys");
system("systemctl restart sshd");
#### make .ssh directory of each node

my $pm = Parallel::ForkManager->new("$forkNo");
for (@avaIP){	
$pm->start and next;
	my $exp = Expect->new;
	$exp = Expect->spawn("ssh -l root $_ \n");
	$exp->expect($expectT,[
						qr/password:/i,
						sub {
								my $self = shift ;
								$self->send("$pass\n");                            
								exp_continue;
							}
					],
					[
						qr/\/\[fingerprint\]\)\?/i,
						sub {
								my $self = shift ;
								$self->send("yes\n");	#first time to ssh into this node				        
								#Are you sure you want to continue connecting (yes/no)?
							}
					]
		); # end of exp 
	#the response after (yes/no)
	#Warning: Permanently added '192.168.0.2' (ECDSA) to the list of known hosts.
	#root@192.168.0.2's password:
				$exp->expect($expectT,[
						qr/password:/i,
						sub {
								my $self = shift ;
								$self->send("$pass\n");      
							}
					]);	
	
	$exp->send ("\n");
	$exp -> send("rm -rf /root/\.ssh\n") if ($exp->expect($expectT,'#'));
   	$exp -> send("mkdir  /root/\.ssh\n") if ($exp->expect($expectT,'#'));
    $exp -> send("chmod 700 /root/\.ssh\n") if ($exp->expect($expectT,'#'));
	$exp -> send("exit\n") if ($exp->expect($expectT,'#'));
	$exp->soft_close();
$pm->finish;
} # end of loop

$pm->wait_all_children;
# Beign scp
print "**********Beign scp\n";
sleep(1);
for (@avaIP){	
	$pm->start and next;
	my $exp = Expect->new;
	$exp = Expect->spawn("scp  /root/\.ssh/authorized_keys root\@$_:/root/\.ssh/ \n");
    $exp->expect($expectT,[
                    qr/password:/i,
                    sub {
                            my $self = shift ;
                            $self->send("$pass\n");     
                         }
                          ]
                 ); # end of exp     
	$exp->soft_close();
	$pm->finish;
}# for loop

$pm->wait_all_children;
sleep(1);
print "**********End scp\n";

#### change mode for 
print "**********Begin chmod\n";
for (@avaIP){	
	$pm->start and next;
	my $exp = Expect->new;
	$exp = Expect->spawn("ssh -l root $_ \n");
    $exp->expect($expectT,[
                    qr/password:/i,
                    sub {
                            my $self = shift ;
                            $self->send("$pass\n");     
                         }
                          ]
                 ); # end of exp 
	
    $exp -> send("\n");
    $exp -> send("chmod 640 /root/\.ssh/authorized_keys\n") if ($exp->expect($expectT,'#'));
   	$exp -> send("systemctl restart sshd \n") if ($exp->expect($expectT,'#'));
	$exp -> send("exit\n") if ($exp->expect($expectT,'#'));
	$exp->soft_close();
	$pm->finish;
}# for loop

$pm->wait_all_children;
print "**********End chmod\n";

######## go through each node for the final passworless setting

for (0..$#avaIP){
	$pm->start and next;
	my $temp=$_+ 1;# from node01
    my $nodeindex=sprintf("%02d",$temp);
    my $nodename= "node"."$nodeindex";
    chomp $nodename;	
    print "**$_ $nodename**\n";
	my $exp = Expect->new;
	$exp = Expect->spawn("ssh $nodename \n");
	$exp->expect($expectT,
					[
						qr/connecting/i,
						sub {
								my $self = shift ;
								$self->send("yes\n");	#first time to ssh into this node				        
								#Are you sure you want to continue connecting (yes/no)?
							}
					]
		); # end of exp 				
	
	$exp->send ("\n") if ($exp->expect($expectT,'#'));
	$exp -> send("exit\n") if ($exp->expect($expectT,'#'));
	$exp->soft_close();
	$pm->finish;
} # end of loop
$pm->wait_all_children;
print "\n\n***###05root_rsa.pl: root passwordless setting done******\n\n";
