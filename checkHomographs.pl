#!/usr/local/bin/perl
use Getopt::Std;
use autodie qw(:all);
use open qw(:std :utf8);
use utf8;
use strict;
our ($LOG, $LOAD, $opt_f, $opt_c, $opt_u, $opt_D, $opt_I, $opt_O, $opt_d, $opt_M, $opt_B, %W, %INFO, %DPSIDS);
our ($hw_tag, $hm_tag, $hm_att, $ERRCT);

our (%H_HM_CT, %H, %MAX_HM);
require "./utils.pl";
require "./restructure.pl";

$LOG = 0;
$LOAD = 0;
$, = ' ';               # set output field separator
$\ = "\n";              # set output record separator
#undef $/; # read in the whole file at once
&main;

sub main
{
    getopts('uf:L:IODMBc:');
    &usage if ($opt_u);
    my($e, $dictCode);
    #   $opt_L = ""; # name of file for the log_fp output to go to
    &open_debug_files;
    use open qw(:utf8 :std);
    if ($opt_D)
    {
	binmode DB::OUT,":utf8";
    }
    if ($opt_M)
    {
	# OxMono
	$hw_tag = "hw";
	$hm_tag = "hw";
	$hm_att = "homograph";
    } elsif ($opt_B)    {	    # OxBi
	$hw_tag = "hw";
	$hm_tag = "hw";
	$hm_att = "hm";
    } else {
	# LeXML2
	$hw_tag = "headword";
	$hm_tag = "headwordUnit";
	$hm_att = "homograph";
    }
    # Go through dictionary and store how many times each h+hm is used
    my $infile = @ARGV[0];
#    $dictCode = &storeInfo($opt_f, $hw_tag, $hm_tag, $hm_att);
    $dictCode = &storeInfo($infile, $hw_tag, $hm_tag, $hm_att);
    if ($dictCode =~ m|^ *$|)
    {
	# if the file hasn't made it into DPS the dictCode won't be on the <dps-data tag so will be supplied as a parameter
	$dictCode = $opt_c;
    }   
#    &reportErrors($opt_f, $hw_tag, $hm_tag, $hm_att, $dictCode);
    &reportErrors($infile, $hw_tag, $hm_tag, $hm_att, $dictCode);
    &close_debug_files;
}

sub reportErrors
{
    my($infile, $hw_tag, $hm_tag, $hm_att, $dictCode) = @_;
    my $ErrorReportInformation = &getErrorReportInformation($infile, $dictCode);
    printf("<errorReport>\n"); 
    printf("$ErrorReportInformation\n"); 
    open(in_fp, "$infile") || die "Unable to open $opt_f";     
  line:    
    while (<in_fp>){
	chomp;       # strip record separator
	s|||g;
	if (m|<$hm_tag[ >]|)
	{
	    if (m| suppressed=\"true\"|i)
	    {
		$_ = &loseSuppressed($_);
	    }
	    if (m|<entry|)
	    {
		my $error_report = &check_hw_hms($_, $hw_tag, $hm_tag, $hm_att);
	    }
	}
  }
    close(in_fp);
    printf("</errorReport>\n"); 
}

sub check_hw_hms
{
    my($e, $hw_tag, $hm_tag, $hm_att) = @_;
    my ($errorTypeDescription, $errorSeverity, $errorContext, $hmSequence, $errorTypeIdentifier, $errorUniqID, $dpsids, $error_p, $errorTypeDescription, $hw_hm);
    # check if there are any errors in this entry
    my $hw = restructure::get_tag_contents($e, $hw_tag); 
    my $hm = restructure::get_tag_attval($e, $hm_tag, $hm_att);
    $hm = 0 if ($hm =~ m|^ *$|);	
    ##
    my $hw_ct = $H{$hw};
    my $max_hm = $MAX_HM{$hw};
    my $hw_no_hm = sprintf("%s\t0", $hw);
    if ($hw_ct == 1)
    {
	# If one use of hw then should be no hm given
	if ($max_hm > 0)
	{
	    $error_p = 1;	      
	    $hw_hm = sprintf("%s\t%s", $hw, $max_hm);
	    $errorTypeDescription = "Redundant homograph number";
	    $errorTypeIdentifier = "101";
	    $errorSeverity = "info";
	    $errorContext = sprintf("No other HMS <error>{hw}%s{/hw}{hm}%s{/hm}</error>", $hw, $max_hm); 
	}
    }
    else
    {
	my $ct = $H_HM_CT{$hw_no_hm};
	if ($ct > 1)
	{
	    $error_p = 1; # more than one without a HM
	    $errorTypeDescription = "Used more than once with no homograph number";
	    $errorTypeIdentifier = "102";
	    $errorSeverity = "error";
	    $errorContext = sprintf("Multiple use of HW without HM <error>{hw}%s{/hw}</error>", $hw); 
	}
	for (my $hm=1; $hm <= $max_hm; $hm++)
	{
	    my $hw_hm = sprintf("%s\t%s", $hw, $hm); 
	    $ct = $H_HM_CT{$hw_hm};
	    if ($ct == 1)
	    {
		$errorContext .= sprintf(" %s", $hm);  # OK
	    }
	    elsif ($ct == 0)
	    {
		$error_p = 1;  # number missing from sequence
		$errorSeverity = "error";
		$errorTypeIdentifier = "103";
		$errorTypeDescription = "Homograph number missing from sequence";
		$errorContext .= sprintf(" <error>-%s</error>", $hm); 
	    }
	    else {
		$error_p = 1;  # number more than once in sequence
		$errorSeverity = "error";
		$errorTypeIdentifier = "104";
		$errorTypeDescription = "Repeat use of homograph number";
		$errorContext .= sprintf(" <error>%s (*%s)</error>", $hm, $ct); 
	    }
	}
    }
    unless ($error_p)
    {
	return "";
    }
    my $entryInformation = &getEntryInformation($e, $hw_tag, $hm_tag, $hm_att);
    my $errorType = sprintf("<errorType><errorTypeIdentifier>%s</errorTypeIdentifier><errorTypeDescription>%s</errorTypeDescription></errorType>", $errorTypeIdentifier, $errorTypeDescription);
    my $errorUniqID = sprintf("<errorUniqID>HMERR%03d</errorUniqID>", ++$ERRCT);
    my $errorNodeInformation = "<errorNodeInformation><nodeNameOrXPath>entry</nodeNameOrXPath></errorNodeInformation>";
    $errorSeverity = sprintf("<errorSeverity>%s</errorSeverity>", $errorSeverity);
    $errorContext = sprintf("<errorContext>%s</errorContext>", $errorContext);
    my $entryErrors = sprintf("<entryErrors><errorInformation>$errorType$errorNodeInformation$errorSeverity$errorContext</errorInformation></entryErrors>");
    my $report = sprintf("<entryReport>$entryInformation$entryErrors</entryReport>"); 
    print $report;
}

sub getEntryInformation
{
    my($e, $hw_tag, $hm_tag, $hm_att) = @_;
    my($dpsid, $dbid, $lexid);	
    if ($e =~ m|^.*? e:id=\"(.*?)\"|)
    {
	$dpsid = $1;
    }
    if ($e =~ m|^.*? e:dbid=\"(.*?)\"|)
    {
	$dbid = $1;
    }
    if ($e =~ m|^.*? lexid=\"(.*?)\"|)
    {
	$lexid = $1;
    }
    my $hw = restructure::get_tag_contents($e, $hw_tag);
    my $hm = restructure::get_tag_attval($e, $hm_tag, $hm_att);
    $hm = 0 if ($hm =~ m|^ *$|);	

    #    my $dpsEntryName = sprintf("%s::%d", $hw, $hm);
    my $entryInformation = sprintf("<entryInformation><headword>$hw</headword><homograph>$hm</homograph><dpsID>$dpsid</dpsID><dpsDBID>$dbid</dpsDBID><lexID>$lexid</lexID></entryInformation>"); 
    return $entryInformation;
}

sub storeInfo
{
    my($infile, $hw_tag, $hm_tag, $hm_att) = @_;
    my $dictCode;
    open(in_fp, "$infile") || die "Unable to open $opt_f";     
  line:    
    while (<in_fp>){
	chomp;       # strip record separator
	s|||g;
	if (m|<dps-data |)
	{
	    s|\'|\"|g;
	    $dictCode = restructure::get_tag_attval($_, "dps-data", "project"); 
	}
	if (m| suppressed=\"true\"|i)
	{
	    $_ = &loseSuppressed($_);
	}
	&store_hw_hms($_, $hw_tag, $hm_tag, $hm_att);
  }
    close(in_fp);
    return($dictCode);
}

sub store_hw_hms
{
    my($e, $hw_tag, $hm_tag, $hm_att) = @_;
    my($dpsid, $dbid, $hw, $hm, $lexid);
    $hw = restructure::get_tag_contents($e, $hw_tag);
    $hm = restructure::get_tag_attval($e, $hm_tag, $hm_att);
    $hm = 0 if ($hm =~ m|^ *$|);	
    my $entryInformation = sprintf("<entryInformation><headword>$hw</headword><dpsEntryName>$hw::$hm</dpsEntryName><dpsID>$dpsid</dpsID><dpsDBID>$dbid</dpsDBID><lexID>$lexid</lexID></entryInformation>"); 
    $INFO{$dpsid} = $entryInformation;
    $hw =~ s|^ *||gi;
    $hw =~ s| *$||gi;
    my $hw_hm = sprintf("%s\t%s", $hw, $hm);
    $H_HM_CT{$hw_hm}++;
    $H{$hw}++;
    if ($hm > $MAX_HM{$hw})
    {
	$MAX_HM{$hw} = $hm;
    }
}

sub getErrorReportInformation
{
    my($f, $dictCode) = @_;
    my $executionTime = &getTime("%Y-%m-%d %H:%M:%S");
    my $fileDate = &getFileModTime($f);
    my $res = sprintf("<errorReportInformation><executionInformation><checkingProgramName>checkHomographs.pl</checkingProgramName><timeProgramExecuted>$executionTime</timeProgramExecuted></executionInformation><sourceInformation><projectNameOrCode>$dictCode</projectNameOrCode><sourceModificationDate>$fileDate</sourceModificationDate><sourceFileName>dps.xml</sourceFileName></sourceInformation></errorReportInformation>"); 
    return $res;
}

sub loseSuppressed
{
    my($e) = @_;
    $e = restructure::delabel($e);	
    while ($e =~ m|(<[^>]* suppressed=\"true\"[^>]*>)|)
    {
	my $tagname = restructure::get_tagname($1);
	$e = restructure::del_tag_with_attrib($e, $tagname, "suppressed", "true");
    }	    
    return $e;
}

sub usage
{
    printf(STDERR "USAGE: $0 [-B|M] dps.xml \n"); 
    printf(STDERR "\t-u:\tDisplay usage\n"); 
    printf(STDERR "\t-B:\tOxBi\n");
    printf(STDERR "\t-M:\tOxMono\n");
    printf(STDERR "\t[-c code]:\tThe dictionary code for the title (if not from DPS)\n"); 
    exit;
}

