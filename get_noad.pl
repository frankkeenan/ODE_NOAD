#!/usr/bin/perl
use Getopt::Std;
use autodie qw(:all);
use utf8;
use strict;
our ($LOG, $LOAD, $opt_f, $opt_u, $opt_D, $opt_I, $opt_O);
require "./utils.pl";
require "./restructure.pl";
#require "/NEWdata/dicts/generic/progs/xsl_lib_fk.pl";
$LOG = 0;
$LOAD = 0;
$, = ' ';               # set output field separator
$\ = "\n";              # set output record separator
#undef $/; # read in the whole file at once
&main;

sub main
{
    getopts('uf:L:IOD');
    &usage if ($opt_u);
    my($e, $res, $bit);
    my(@BITS);
    #   $opt_L = ""; # name of file for the log_fp output to go to
    use open qw(:std :utf8);
    &open_debug_files;
    if ($opt_D)
    {
	binmode DB::OUT,":utf8";
    }
  line:    
    while (<>){
	chomp;       # strip record separator
	s|||g;
	if ($opt_I){printf(bugin_fp "%s\n", $_);}
	#	unless (m|<entry|){print $_; next line;}
	#	$e = restructure::strip_dps($e); 
	# s|<!--.*?-->||gio;
	#	next line if (m|<entry[^>]*del=\"y|io);
	#	next line if (m|<entry[^>]*sup=\"y|io);
	# $h = &get_hex_h($_, "hex", 1); # the 1 says to remove stress etc
	# $eid = &get_tag_attval($_, "entry", "eid");
	# $e_eid = &get_dps_entry_id($_);
	# $_ = &reduce_idmids($_);
	# s|£|&\#x00A3;|g;
        $_ = restructure::delabel($_);	
	s| regionalization=\"US\"| Bregionalization=\"US\"|gi;
	s| regionalization=\" *\"||gi;
      wloop:
	while (m|(<[^>]* regionalization=\".*?\".*?>)|)
      {
	  my $tagname = restructure::get_tagname($1);    
	  my $pre = $_;
	  $_ = &remove_regionalizations($_, $tagname);
	  if ($_ eq $pre)
	  {
	      # avoid infinite loop
	      last wloop;	      
	  }
      }
	s| Bregionalization=| regionalization=|gi;
	print $_;
	if ($opt_O){printf(bugout_fp "%s\n", $_);}
    }
    &close_debug_files;
}

sub remove_regionalizations
{
    my($e, $tagname) = @_;
    my($res, $eid);	
    my($bit, $res);
    my(@BITS);
    $e =~ s|(<$tagname[ >].*?</$tagname>)|&split;&fk;$1&split;|gi;
    @BITS = split(/&split;/, $e);
    $res = "";
    foreach $bit (@BITS){
	if ($bit =~ s|&fk;||gi){
	    my $region = restructure::get_tag_attval($bit, $tagname, "regionalization");
	    unless ($region =~ m|^ *$|)
	    {
		$bit = "";
	    }
	}
	$res .= $bit;
    }    
    return $res;
}

sub usage
{
    printf(STDERR "USAGE: $0 -u \n"); 
    printf(STDERR "\t-u:\tDisplay usage\n"); 
    #    printf(STDERR "\t-x:\t\n"); 
    exit;
}
