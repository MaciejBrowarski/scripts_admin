#!/usr/bin/perl -w
#
# Version: 7.0
#
# History:
# 0.1.0 2010 August - Created
# 0.2.0 2013 Februrary - add diff compare and backup functionality
# 0.3 2014 March - add version when msync is launched
# 0.4 2014 October - add debug
# 0.5 2014 November - consolided for one script with symlink
# 0.6 2014 December - evaluate to array for subfolders
# 0.6.1 2014 December - add list command
# 0.6.2 2015 January - add backup folder
# 0.6.3 2015 January - put version command
# 0.6.4 2017 January - add www
# 7.0 2018 March - add md5sum for file in version file
#
# Copyrigth by BROWARSKI
#
# $0<script_name> ARGV[0]<cmp/msync> ARGV[1]<action>
# 
# cmp - copy from IDS to disk
# msync - copy from folder to IDS
#
# scripts_name:
# scripts
# scripts_admin
# netbone
# idscron
#
use Digest::MD5 qw(md5_hex);
use File::Path qw( make_path );

my $action = 0;
my %dfile;
my %mfile;
my $debug = 0;
# when last change occur - use by version
my $last_t = 0;

my %dfile_mode;
my %mfile_mode;

my @dir_ids;
my @dir_sc;
my @dir_backup;

my $sa;

my $cl = "$ENV{'HOME'}/get/netbone/bin/filec";
#
# on what host we run it (for flow) - msync allow only on ns3 server
#
my $host = `/bin/hostname`;
chomp $host;

# my $b_dir = $ENV{'HOME'}."/get/backup/scripts/";
#
# required systems:  agent idscron netbone scripts scripts_admin sms watchdog
#
if ($0 =~ /agent\.pl$/) {
	# no slash on end !!
	@dir_ids = ("/repo/agent/source", "/repo/agent");
        @dir_sc = ($ENV{HOME}."/get/agent/source", $ENV{HOME}."/get/agent");
	@dir_backup = ($ENV{HOME}."/get/backup/agent/source", $ENV{HOME}."/get/backup/agent");
}
if ($0 =~ /netbone\.pl$/) {
        # no slash on end !!
        @dir_ids = ("/repo/netbone/source", "/repo/netbone");
        @dir_sc = ($ENV{HOME}."/get/netbone/source", $ENV{HOME}."/get/netbone");
	@dir_backup = ($ENV{HOME}."/get/backup/netbone/source", $ENV{HOME}."/get/backup/netbone");
}

if ($0 =~ /idscron\.pl$/) {
        # no slash on end !!
        @dir_ids = ("/repo/idscron/cfg", "/repo/idscron/source", "/repo/idscron");
        @dir_sc = ($ENV{HOME}."/get/idscron/cfg", $ENV{HOME}."/get/idscron/source", $ENV{HOME}."/get/idscron");
	@dir_backup = ($ENV{HOME}."/get/backup/idscron/cfg", $ENV{HOME}."/get/backup/idscron/source", $ENV{HOME}."/get/backup/idscron");

}
if ($0 =~ /www\.pl$/) {
        # no slash on end !!
        @dir_ids = ("/repo/www");
        @dir_sc =  ($ENV{HOME}."/get/www");
        @dir_backup = ($ENV{HOME}."/get/backup/www");
}


if ($0 =~ /scripts\.pl$/) { 
	# no slash on end !!
        @dir_ids = ("/repo/scripts");
        @dir_sc = ($ENV{HOME}."/get/scripts");
	@dir_backup = ($ENV{HOME}."/get/backup/scripts");
}


if ($0 =~ /watchdog\.pl$/) {
        # no slash on end for both array !!
        @dir_ids = ("/repo/watchdog/cfg", "/repo/watchdog/source", "/repo/watchdog");
        @dir_sc = ($ENV{HOME}."/get/watchdog/cfg", $ENV{HOME}."/get/watchdog/source", $ENV{HOME}."/get/watchdog");
	@dir_backup = ($ENV{HOME}."/get/backup/watchdog/cfg", $ENV{HOME}."/get/backup/watchdog/source", $ENV{HOME}."/get/backup/watchdog");
}


if ($0 =~ /sms\.pl$/) {
        # no slash on end for both array !!
        @dir_ids = ("/repo/sms/cfg", "/repo/sms/source", "/repo/sms");
        @dir_sc = ($ENV{HOME}."/get/sms/cfg", $ENV{HOME}."/get/sms/source", $ENV{HOME}."/get/sms");
	@dir_backup = ($ENV{HOME}."/get/backup/sms/cfg", $ENV{HOME}."/get/backup/sms/source", $ENV{HOME}."/get/backup/sms");
}

if ($0 =~ /scripts_admin\.pl$/) { 
	# no slash on end !!
	@dir_ids = ("/repo/scripts_admin");
	@dir_sc = ($ENV{HOME}."/get/scripts_admin");
	@dir_backup = ($ENV{HOME}."/get/backup/scripts_admin");
}

(@dir_sc) or die "No rules defined\n";
#
# get files stat from IDS
#
sub r_mfile 
{
	my ($dir) = shift;
	open PLIK, "$cl list $dir | " or die "unable to run $cl list $dir: $!\n";
	while ($l = <PLIK>) {
		chomp $l;
		my $f_n = "$dir"."$l";
		open INFO, "$cl info $f_n | " or die "unable to run $cl info $l: $!\n";
		my $size = 0;
		my $mode = 0;
		my $time = 0;
		while (my $m = <INFO>) {
			chomp $m;
			if ($m =~ /size=(\d+)/) { $size = $1; }
			if ($m =~ /mode=(\d+)/) { $mode = $1; }
			if ($m =~ /ctime=(\d+)/) { $time = $1; }
		}
		if ($mode & 040000) { 
			$debug and print "memory dir: $f_n\n";
			r_mfile ("$f_n");
		}	
		$time or next;
		$mfile{"$l"} = $time;
		$debug and printf ("memory: $l mode %o time %s\n", $mode, localtime($time));

		$mfile_mode{"$l"} = $mode;

		close INFO;
	}
	close PLIK;
}
#
# load files from disk
#
sub r_dfile {
	my ($dir) = shift;
	my $directory;

	opendir ($directory, "$dir") or die "unable to open dir $dir: $!\n";
	foreach my $file (readdir ($directory)) {
		($file =~ /^\./) and next;
		my $full = "$dir"."$file";
		if ($dir eq ".") {
			$full = $file;
		}
		#
		# omit symlinks and directories
		#
		((-d $full) || (-l $full)) and next;
		#
		# omit object file
		#
		($full =~ /\.o$/) and next;

		my @stat = lstat($full);

		if (($stat[2] & 0120000) == 0120000) { 
			$debug and printf ("$full: symlink mode %o\n", $stat[2]); 
		}
		$debug and printf ("disk: $file time %s mode %o\n",  localtime($stat[9]), $stat[2]);
		# add to hash
		$dfile{"$full"} = $stat[9];
		$dfile_mode{"$full"} = $stat[2];
	}
	closedir ($directory); 
}
#
# scan folder and update global variable last_t with last modification time
#
sub get_last_t {
	my $dir = shift;
	my $d;
	opendir $d, $dir or die "unable to open $dir: $!\n";
	foreach my $f (readdir ($d)) {	
		($f =~ /^\./) and next;
		#
                # omit symlinks
                #
		my $full = $dir."/".$f;
	#	$debug and print "get_last_t: $full\n";

                ((-l $full) || (-d $full)) and next;
		 #
                # omit object file
                #
                ($full =~ /\.o$/) and next;


                my @stat = lstat($full);
                my $c = $stat[9];
		$debug and print "$full has ".localtime($c)."\n";
                (!($f eq "version")) and  ($last_t < $c) and $last_t = $c;

	}
	closedir $d;
}

my %md5_file;

sub get_md5sum {
    my $dir = shift;
    my $d;
    opendir $d, $dir or die "unable to open $dir: $!\n";
    foreach my $f (readdir ($d)) {
        ($f =~ /^\./) and next;
        my $full = $dir."/".$f;

        ((-l $full) || (-d $full)) and next;
        #
        # omit object file
        #   
        ($full =~ /\.o$/) and next;
        my $data;

        open FILE, $full or die "unable to open $full: $!\n";

        while (<FILE>) {
            $data .= $_;
        }
        close FILE;    
                
        my $m = md5_hex($data);
        $md5_file{$full} = $m;
    }
}




$ARGV[0] or die "cmp/msync/list?\n";
$ARGV[1] and $action = 1;

#
# determine direction
# cmp: kier = 0 
# msync: kier = 1
#
my $kier = 0;
my $version = 0;
if ($ARGV[0] eq  "msync") {
        $kier = 1;
}

if ($ARGV[0] eq "check") {
	print "not yet implemented\n";
	exit;
}
#
# version - set version to folder without put it IDS
#
if ($ARGV[0] eq "version") {
	$version = 1;
	$kier = 1;
}
if ($ARGV[0] eq "list") {
	foreach my $l (@dir_ids) {
		$l =~ s/\s*$//;
		# print "L: $l\n";
		if ($l =~ m|/([\w\d\_]+)$|) {
			my $p = $1;
			my $r = $l;
			$r =~ s|$p$||;
			# print "R $r P $p\n";
			my $exec = $cl." list $r";
			# print "EXEC: $exec\n";
			if (open PLIK, "$exec |") {
				while (<PLIK>) {
					chomp;
					# print "PR: $_\n";
					/$p$/ and print $r."$_\n";
					/$p\_\d/ and print $r."$_\n";
				}
				close PLIK;
			}
		}
	}
	exit;
}
#
# date&time for backup file when cmp
#
my @d = localtime();
my $a = sprintf("%04d%02d%02d-%02d%02d", $d[5] + 1900, $d[4] + 1, $d[3], $d[2], $d[1]);

#
# put version to file
#
if ($kier) {
	#
	# scan all files to get last update
	#
	my $l_f; 
	foreach my $f (@dir_sc) {
		get_last_t($f);
        get_md5sum($f);
		$l_f = $f;
	} 
        #
        # put version same as last update from directory
        #
        my @ti = localtime($last_t);
        $sa = sprintf("%04d%02d%02d-%02d%02d%02d", $ti[5] + 1900, $ti[4] + 1, $ti[3], $ti[2], $ti[1], $ti[0]);
	#
	# correct version file in last directory in array
	#
	$debug and print "Version: $l_f/version : $sa\n";
        if (open VER, "> $l_f/version") {
                print VER "$sa\n";
                close VER;
        } else {
                die "nie mozna zmienic version: $!\n";
        }
        #
        # put all md5 digist to version file too
        #

        open MD5, ">> $l_f/version" or die "unable to open version: $!\n"; 
        foreach my $k (sort keys %md5_file) {
           
           print MD5 $k." - ".$md5_file{$k}."\n";
              
        }
            close MD5;
        utime $last_t, $last_t, "$l_f/version";
}
#
# is version set, mean we just update version file and exit
#
if ($version) { 
	print "Updated with: $sa\n";
	exit;
}



my $i_ids = @dir_ids;
my $i_sc = @dir_sc;

($i_ids == $i_sc) or die "folder numbers in dir_sc diffrent than in dir_ids\n";

for (my $i = 0; $i < $i_sc; $i++) {
	my (%from, %to, %from_mode, %to_mode);

	($dir_ids[$i]  =~ m|/$|) and die "\n!!!\nDetected / on end IDS: index $i - $dir_ids[$i], please correct\n";
        ($dir_sc[$i]  =~ m|/$|) and die "\n!!!\nDetected / on end SC: index $i - $dir_sc[$i], please correct\n";

	chdir $dir_sc[$i] or die "unable to chdir $dir_sc[$i]\n";

	%dfile_mode = ();
	%mfile_mode = ();
	%dfile = ();
	%mfile = ();


	r_dfile (".");
	r_mfile ($dir_ids[$i]."/");

	if ($kier) {
		%from = %dfile;
		%from_mode = %dfile_mode;
	        %to = %mfile;
		%to_mode = %mfile_mode;
	} else {
	# # from memory to disk
	#
		%from = %mfile;
		%from_mode = %mfile_mode;
	        %to = %dfile;
		%to_mode = %dfile_mode;
		my $kn = keys %from;
                $kn or die "No files in IDS..exit\n";
	}
	
	$debug and print "SC $dir_sc[$i] IDS $dir_ids[$i]\n";

	foreach my $k (keys %from) {
		$debug and print "From $k: ".localtime($from{$k})."\n";
	}
	#
	#  check is any file in destination to need to be deleted
	#
	foreach my $k (keys %to) {
		 $debug and print "To $k: ".localtime($from{$k})."\n";
		if ((! (exists ($from{$k}))) && ($to{$k} )) {
			#
			# delete file in destination
			#
			print "Delete: $k\n";
			if ($kier) {
				my $t_n = "$dir_ids[$i]"."/$k";
				my $exec = "$cl delete_r \"$t_n\"\n";
				print "$exec";
				if ($action) {  system $exec or warn "unable to delete $exec: $!\n"; }
			} else {
	        		my $t_n = $dir_sc[$i]."/$k";
	
				if ($action) {  unlink "$t_n" or die "unable to unlink $t_n: $!\n"; }
			}
			delete $to{$k};
		}
	} 

	foreach my $k (keys %from) {
		$debug and print "Test file $k\n";
		#
		# if files are same, search another candidate
		#
		((exists $to{$k}) && ($from{$k} == $to{$k})) and next;
		#
		# if any files has 0 modify time, don't go futher
		# 
		if ((exists $to{$k}) && (! $to{$k})) { next; }
		if ((exists $from{$k}) && (! $from{$k})) { next; }
		#
		# copy file
		#
		# msync - disk to memory
		#
		my $f_n = $dir_sc[$i]."/$k";
	        my $t_n = $dir_ids[$i]."/$k";
		$debug and print "File $f_n SC $t_n\n";
	 
		if ($kier) {
			if (-d $f_n) { print "OMIT: $f_n is directory\n"; next; }
			my $diff = "$cl get \"$t_n\" | diff -Naur - \"$f_n\" ";
	               $debug and  print "MSYNC diff $diff\n";
			  my $ret =  system $diff;
	               $ret or next;
	
			my $exec = "$cl lput \"$t_n\"  \"$f_n\"";
			my $b_exec = "$cl lput \"".$dir_ids[$i]."_$sa/$k\" \"$f_n\"";
	                print "PLAN: $exec\nB_PLAN $b_exec\n";
	
	                print "$exec\n";
				
	                if ($action)  { 
				my $ret = system $exec; 
				($ret < 1) and warn "problem with system $exec: $!\n"; 
				$ret = system $b_exec;	
				($ret < 1) and warn "problem with back system $exec: $!\n";
			}
	
		} else {
			my $exec = "$cl get \"$t_n\" > \"$f_n\"";
			my $diff = "$cl get \"$t_n\" | diff -Naur \"$f_n\" -";
			$debug and print "CMP diff $diff\n";
	               my $ret =  system $diff;
	               $ret or next;
	                print "PLAN: $exec\n";
	
			my $m = $from_mode{$k} & 0777;
			if (!$m) { 
				if (($t_n =~ /\.pl$/)||($t_n =~ /.sh$/)) { 
					$m = 0755; 
				} else {
					$m = 0644;
				} 
			}
			printf ("/bin/chmod %o  $f_n\n", $m);
			my $b_dir = $dir_backup[$i];
			if (! -d $b_dir) {	
				print "Create dir for backup: $b_dir\n";
				$action and make_path($b_dir);
			}
			my $d_file = $b_dir."/".(split /\//, $f_n)[-1].".$a";
			my $exec_cp = "/bin/cp $f_n $d_file";
	                print "BACKUP $exec_cp\n";
	
			if ($action) {  
				system ($exec_cp) and warn "problem with b copy: $!\n";
				print "$exec\n";
				system $exec or warn "problem with system: $!\n"; 
				utime $from{$k}, $from{$k}, $f_n or warn "problem with utime: $t_n $!\n"; 
			#	my $m = $from_mode{$k} & 0777;
				chmod $m, $f_n;
			}
			
		}
	}
}

$warning and print $warning;
