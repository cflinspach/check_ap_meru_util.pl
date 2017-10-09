#!/usr/bin/perl
# About: Check plugin for nagios/icinga to check utilization of Meru AP's
# 
# Usage: 
#
# Version 1.0
# Author: Casey Flinspach
#         cflinspach@protonmail.com
#
#################################################################################

use strict;
use warnings;
use Net::SNMP;
use Getopt::Long qw(:config no_ignore_case);
use List::MoreUtils qw(pairwise);
use Net::Ping;

my $hostaddr = '';
my $community = '';
my $ap_tx_util_oid = '';
my $ap_rx_util_oid = '';
my $ap_name_oid = '';

GetOptions(
		"help|h-" => \my $help,
        "Host|H=s" => \$hostaddr,
        "community|C=s" => \$community,
        "ap_tx_util_oid|t=s" => \$ap_tx_util_oid,
        "ap_rx_util_oid|r=s" => \$ap_rx_util_oid,
        "ap_name_oid|O=s" => \$ap_name_oid);

if($help) {
        help();
        exit;
}


sub help { print "
About: Check plugin for nagios/icinga to record utilization of Meru AP's.

Currently does not have warning or critical thresholds and is used primarily to gather data for graphs.

Usage:
check_ap_meru_util.pl -H [host] -C [community] -O [ap name oid] -r [ap receive oid] -t [ap transmit oid]

Meru example:
check_ap_meru_util.pl -H 192.168.0.6 -C public -O .1.3.6.1.4.1.15983.1.1.4.2.1.1.2 -r .1.3.6.1.4.1.15983.1.1.3.1.7.1.10 -t .1.3.6.1.4.1.15983.1.1.3.1.7.1.11

";
}

my ($session, $error) = Net::SNMP->session(
                        -hostname => "$hostaddr",
                        -community => "$community",
                        -timeout => "30",
                        -version => "2c",
                        -port => "161");

if (!defined($session)) {
        printf("ERROR: %s.\n", $error);
        help();
        exit 1;
}

my $ap_tx_util = $session->get_table( -baseoid => $ap_tx_util_oid );
my $ap_rx_util = $session->get_table( -baseoid => $ap_rx_util_oid );
my $ap_name = $session->get_table( -baseoid => $ap_name_oid);

if (! defined $ap_tx_util || ! defined $ap_rx_util || ! defined $ap_name ) {
    die "ERROR: " . $session->error;
    $session->close();
}

my $err = $session->error;
if ($err){
        print $err;
        return 1;
}

my @ap_tx_name_array;
my @ap_rx_name_array;
foreach my $ap_name_key (keys %$ap_name) {
	push(@ap_tx_name_array,$ap_name->{$ap_name_key});
        push(@ap_rx_name_array,$ap_name->{$ap_name_key});
}

my @ap_tx_util_array;
foreach my $ap_tx_util_key (keys %$ap_tx_util) {
	push(@ap_tx_util_array,$ap_tx_util->{$ap_tx_util_key});
}

my @ap_rx_util_array;
foreach my $ap_rx_util_key (keys %$ap_rx_util) {
        push(@ap_rx_util_array,$ap_rx_util->{$ap_rx_util_key});
}

my %tx_result =  ();
foreach (0..scalar(@ap_tx_name_array)-1){
	if (!exists $tx_result{"$ap_tx_name_array[$_]"}){
        $tx_result{"$ap_tx_name_array[$_]"} = $ap_tx_util_array[$_];
    }
    else{
        my $tx_sum = 0;
        $tx_sum = $tx_result{$ap_tx_name_array[$_]};
        my $tx_new = $tx_sum + $ap_tx_util_array[$_];
        $tx_result{"$ap_tx_name_array[$_]"} = $tx_new;
    }
}

my %rx_result =  ();
foreach (0..scalar(@ap_rx_name_array)-1){
        if (!exists $rx_result{"$ap_rx_name_array[$_]"}){
        $rx_result{"$ap_rx_name_array[$_]"} = $ap_rx_util_array[$_];
    }
    else{
        my $rx_sum = 0;
        $rx_sum = $rx_result{$ap_rx_name_array[$_]};
        my $rx_new = $rx_sum + $ap_rx_util_array[$_];
        $rx_result{"$ap_rx_name_array[$_]"} = $rx_new;
    }
}

print "Utilization counts in bytes per second | ";
foreach (sort keys %tx_result) {
	if ( defined $tx_result{$_} ) {
		print "'$_ out:'=$tx_result{$_} ";
	}
}
foreach (sort keys %rx_result) {
	if ( defined $rx_result{$_} ) {
        print "'$_ in:'=$rx_result{$_} ";
    }
}
print "\n";
$session->close();
exit 0;
