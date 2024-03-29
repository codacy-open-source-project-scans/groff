#!/usr/bin/env perl

package main;

########################################################################
# debugging
########################################################################

# See 'Mastering Perl', chapter 4.

# use strict;
# use warnings;
# use diagnostics;

use Carp;
$SIG{__DIE__} = sub { &Carp::croak; };

use Data::Dumper;

########################################################################
# Legalese
########################################################################

our $Legalese;

{
  use constant VERSION => '1.3.2'; # version of glilypond

### This constant 'LICENSE' is the license for this file 'GPL' >= 3
  use constant LICENSE => q*
glilypond - integrate 'lilypond' into 'groff' files

Copyright (C) 2013-2020 Free Software Foundation, Inc.
  Written by Bernd Warken <groff-bernd.warken-72@web.de>

This file is part of 'GNU groff'.

  'GNU groff' is free software: you can redistribute it and/or modify it
under the terms of the 'GNU General Public License' as published by the
'Free Software Foundation', either version 3 of the License, or (at your
option) any later version.

  'GNU groff' is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 'GNU
General Public License' for more details.

  You should have received a copy of the 'GNU General Public License'
along with 'groff', see the files 'COPYING' and 'LICENSE' in the top
directory of the 'groff' source package.  If not, see
<http://www.gnu.org/licenses/>.
*;


  $Legalese =
    {
     'version' => VERSION,
     'license' => LICENSE,
    }

}

##### end legalese


########################################################################
# global variables and BEGIN
########################################################################

use integer;
use utf8;

use Cwd qw[];
use File::Basename qw[];
use File::Copy qw[];
use File::HomeDir qw[];
use File::Spec qw[];
use File::Path qw[];
use File::Temp qw[];
use FindBin qw[];
use POSIX qw[];


BEGIN {

  use constant FALSE => 0;
  use constant TRUE => 1;
  use constant EMPTYSTRING => '';
  use constant EMPTYARRAY => ();
  use constant EMPTYHASH => ();

  our $Globals =
    {
     'before_make' => FALSE,
     'groff_version' => EMPTYSTRING,
     'prog' => EMPTYSTRING,
    };

  ( undef, undef, $Globals->{'prog'} ) = File::Spec->splitpath($0);
  # $Globals->{'prog'} is 'glilypond' when installed,
  # 'glilypond.pl' when not


  $\ = "\n";	# adds newline at each print
  $/ = "\n";	# newline separates input
  $| = 1;       # flush after each print or write command


  {
    {
      # script before run of 'make'
      my $at = '@';
      $Globals->{'before_make'} = TRUE if '@VERSION@' eq "${at}VERSION${at}";
    }

    my $file_test_pl;
    my $glilypond_libdir;

    if ( $Globals->{'before_make'} ) { # in source, not yet installed
      my $glilypond_dir = $FindBin::Bin;
      $glilypond_dir = Cwd::realpath($glilypond_dir);
      $glilypond_libdir = $glilypond_dir;

    } else {			# already installed
      $Globals->{'groff_version'} = '@VERSION@';
      $glilypond_libdir = '@glilypond_dir@';
    }

    unshift(@INC, $glilypond_libdir);

    umask 0077; # octal output: 'printf "%03o", umask;'
  }

  use integer;
  use utf8;
  use feature 'state';

  my $P_PIC;
  # $P_PIC = '.PDFPIC';
  $P_PIC = '.PSPIC';

  ######################################################################
  # subs for using several times
  ######################################################################

  sub create_ly2eps {		       # '--ly2eps' default
    our ( $out, $Read, $Temp );

    my $prefix = $Read->{'file_numbered'};   # w/ dir change to temp dir

    # '$ lilypond --ps -dbackend=eps -dgs-load-fonts \
    #      output=file_without_extension file.ly'
    # extensions are added automatically
    my $opts = '--ps -dbackend=eps -dinclude-eps-fonts -dgs-load-fonts'
      . " --output=$prefix $prefix";
    &run_lilypond("$opts");

    Cwd::chdir $Temp->{'cwd'} or
	die "Could not change to former directory '" .
	  $Temp->{'cwd'} . "': $!";

    my $eps_dir = $Temp->{'eps_dir'};
    my $dir = $Temp->{'temp_dir'};
    opendir( my $dh, $dir ) or
      die "could not open temporary directory '$dir': $!";

    my $re = qr<
		 ^
		 $prefix
		 -
		 .*
		 \.eps
		 $
	       >x;
    my $file;
    while ( readdir( $dh ) ) {
      chomp;
      $file = $_;
      if ( /$re/ ) {
	my $file_path = File::Spec->catfile($dir, $file);
	if ( $eps_dir ) {
	  my $could_copy = FALSE;
	  File::Copy::copy($file_path, $eps_dir)
	      and $could_copy = TRUE;
	  if ( $could_copy ) {
	    unlink $file_path;
	    $file_path = File::Spec->catfile($eps_dir, $_);
	  }
	}
	$out->print( $P_PIC . ' ' . $file_path );
      }
    }				# end while readdir
    closedir( $dh );
  }				# end sub create_ly2eps()


  sub create_pdf2eps {		       # '--pdf2eps'
    our ( $v, $stdout, $stderr, $out, $Read, $Temp );

    my $prefix = $Read->{'file_numbered'};   # w/ dir change to temp dir

    &run_lilypond("--pdf --output=$prefix $prefix");

    my $file_pdf = $prefix . '.pdf';
    my $file_ps = $prefix . '.ps';

    # pdf2ps in temp dir
    my $temp_file = &next_temp_file;
    $v->print( "\n##### run of 'pdf2ps'" );
    # '$ pdf2ps file.pdf file.ps'
    my $output = `pdf2ps $file_pdf $file_ps 2> $temp_file`;
    die 'Program pdf2ps does not work.' if ( $? );
    &shell_handling($output, $temp_file);
    $v->print( "##### end run of 'pdf2ps'\n" );

    # ps2eps in temp dir
    $temp_file = &next_temp_file;
    $v->print( "\n##### run of 'ps2eps'" );
    # '$ ps2eps file.ps'
    $output = `ps2eps $file_ps 2> $temp_file`;
    die 'Program ps2eps does not work.' if ( $? );
    &shell_handling($output, $temp_file);
    $v->print( "##### end run of 'ps2eps'\n" );

    # change back to former dir
    Cwd::chdir $Temp->{'cwd'} or
	die "Could not change to former directory '" .
	  $Temp->{'cwd'} . "': $!";

    # handling of .eps file
    my $file_eps = $prefix . '.eps';
    my $eps_path = File::Spec->catfile($Temp->{'temp_dir'}, $file_eps);
    if ( $Temp->{'eps_dir'} ) {
      my $has_copied = FALSE;
      File::Copy::copy( $eps_path, $Temp->{'eps_dir'} )
	  and $has_copied = TRUE;
      if ( $has_copied ) {
	unlink $eps_path;
	$eps_path = File::Spec->catfile( $Temp->{'eps_dir'}, $file_eps );
      } else {
	$stderr->print( "Could not use EPS-directory." );
      } # end Temp->{'eps_dir'}
    }
    # print into groff output
    $out->print( $P_PIC . ' ' . $eps_path );
  }				# end sub create_pdf2eps()


  sub is_subdir {		# arg1 is subdir of arg2 (is longer)
    my ( $dir1, $dir2 ) = @_;
    $dir1 = &path2abs( $dir1 );;
    $dir2 = &path2abs( $dir2 );;
    my @split1 = File::Spec->splitdir($dir1);
    my @split2 = File::Spec->splitdir($dir2);
    for ( @split2 ) {
      next if ( $_ eq shift @split1 );
      return FALSE;
    }
    return TRUE;
  }


  sub license {
    our ( $Legalese, $stdout );
    &version;
    $stdout->print( $Legalese->{'license'} );
  } # end sub license()


  sub make_dir {		# make directory or check if it exists
    our ( $v, $Args );

    my $dir_arg = shift;
    chomp $dir_arg;
    $dir_arg =~ s/^\s*(.*)\s*$/$1/;

    unless ( $dir_arg ) {
      $v->print( "make_dir(): empty argument" );
      return FALSE;
    }

    unless ( File::Spec->file_name_is_absolute($dir_arg) ) {
      my $res = Cwd::realpath($dir_arg);
      $res = File::Spec->canonpath($dir_arg) unless ( $res );
      $dir_arg = $res if ( $res );
    }

    return $dir_arg if ( -d $dir_arg && -w $dir_arg );


    # search thru the dir parts
    my @dir_parts = File::Spec->splitdir($dir_arg);
    my @dir_grow;
    my $dir_grow;
    my $can_create = FALSE;	# dir could be created if TRUE

   DIRPARTS: for ( @dir_parts ) {
      push @dir_grow, $_;
      next DIRPARTS unless ( $_ ); # empty string for root directory

      # from array to path dir string
      $dir_grow = File::Spec->catdir(@dir_grow);

      next DIRPARTS if ( -d $dir_grow );

      if ( -e $dir_grow ) {  # exists, but not a dir, so must be removed
	die "Couldn't create dir '$dir_arg', it is blocked by "
	  . "'$dir_grow'." unless ( -w $dir_grow );

	# now it's writable, but not a dir, so it can be removed
	unlink ( $dir_grow ) or
	  die "Couldn't remove '$dir_grow', " .
	    "so I cannot create dir '$dir_arg': $!";
      }

      # $dir_grow no longer exists, so the former dir must be writable
      # in order to create the directory
      pop @dir_grow;
      $dir_grow = File::Spec->catdir(@dir_grow);

      die "'$dir_grow' is not writable, " .
	"so directory '$dir_arg' can't be created."
	  unless ( -w $dir_grow );

      # former directory is writable, so '$dir_arg' can be created

      File::Path::make_path( $dir_arg,
			     {
			      mask => oct('0700'),
			      verbose => $Args->{'verbose'},
			     }
			   )	#  'mkdir -P'
	  or die "Could not create directory '$dir_arg': $!";

      last DIRPARTS;
    }

    die "'$dir_arg' is not a writable directory"
      unless ( -d $dir_arg && -w $dir_arg );

    return $dir_arg;

  } # end sub make_dir()


  my $number = 0;
  sub next_temp_file {
    our ( $Temp, $v, $Args );
    ++$number;
    my $temp_basename = $Args->{'prefix'} . '_temp_' . $number;
    my $temp_file = File::Spec->catfile( $Temp->{'temp_dir'} ,
					 $temp_basename );
    $v->print( "next temporary file: '$temp_file'" );
    return $temp_file;
  }				# end sub next_temp_file()


  sub path2abs {
    our ( $Temp, $Args );

    my $path = shift;
    $path =~ s/
		^
		\s*
		(
		  .*
		)
		\s*
		$
	      /$1/x;

    die "path2abs(): argument is empty." unless ( $path );

    # Perl does not support shell '~' for home dir
    if ( $path =~ /
		    ^
		    ~
		  /x ) {
      if ( $path eq '~' ) {	# only own home
	$path = File::HomeDir->my_home;
      } elsif ( $path =~ m<
			    ^
			    ~ /
			    (
			      .*
			    )
			    $
			  >x ) {	# subdir of own home
	$path = File::Spec->catdir( $Temp->{'cwd'}, $1 );
      } elsif ( $path =~ m<
			    ^
			    ~
			    (
			      [^/]+
			    )
			    $
			  >x ) {	# home of other user
	$path = File::HomeDir->users_home($1);
      } elsif ( $path =~ m<
			    ^
			    ~
			    (
			      [^/]+
			    )
			    /+
			    (
			      .*
			    )
			    $
			  >x ) {	# subdir of other home
	$path = File::Spec->
	  catdir( File::HomeDir->users_home($1), $2 );
      }
    }

    $path = File::Spec->rel2abs($path);

    # now $path is absolute
    return $path;
  } # end sub path2abs()


  sub run_lilypond {
    # arg is the options collection for 'lilypond' to run
    # either from ly or pdf

    our ( $Temp, $v );

    my $opts = shift;
    chomp $opts;

    my $temp_file = &next_temp_file;
    my $output = EMPTYSTRING;

    # change to temp dir
    Cwd::chdir $Temp->{'temp_dir'} or
	die "Could not change to temporary directory '" .
	  $Temp->{'temp_dir'} . "': $!";

    $v->print( "\n##### run of 'lilypond " . $opts . "'" );
    $output = `lilypond $opts 2>$temp_file`;
    die "Program lilypond does not work, see '$temp_file': $?"
      if ( $? );
    chomp $output;
    &shell_handling($output, $temp_file);
    $v->print( "##### end run of 'lilypond'\n" );

    # stay in temp dir
  } # end sub run_lilypond()


  sub shell_handling {
    # Handle ``-shell-command output in a string (arg1).
    # stderr goes to temporary file $TempFile.

    our ( $out, $v, $Args );

    my $out_string = shift;
    my $temp_file = shift;

    my $a = &string2array($out_string); # array ref
    for ( @$a ) {
      $out->print( $_ );
    }

    $temp_file && -f $temp_file && -r $temp_file ||
      die "shell_handling(): $temp_file is not a readable file.";
    my $temp = new FH_READ_FILE($temp_file);
    my $res = $temp->read_all();
    for ( @$res ) {
      chomp;
      $v->print($_);
    }

    unlink $temp_file unless ( $Args->{'keep_all'} );
  } # end sub shell_handling()


  sub string2array {
    my $s = shift;
    my @a = ();
    for ( split "\n", $s ) {
      chomp;
      push @a, $_;
    }
    return \@a;
  } # end string2array()


  sub usage {			# for '--help'
    our ( $Globals, $Args );

    my $p = $Globals->{'prog'};
    my $usage = EMPTYSTRING;
    $usage = '###### usage:' . "\n" if ( $Args->{'verbose'} );
    $usage .= qq*Options for $p:
Read a 'roff' file or standard input and transform 'lilypond' parts
(everything between '.lilypond start' and '.lilypond end') into
'EPS'-files that can be read by groff using '.PSPIC'.

There is also a command '.lilypond include <file_name>' that can
include a complete 'lilypond' file into the 'groff' document.


# Breaking options:
$p -?|-h|--help|--usage    # usage
$p --version               # version information
$p --license               # the license is GPL >= 3


# Normal options:
$p [options] [--] [filename ...]

There are 2 options for influencing the way how the 'EPS' files for the
'roff' display are generated:
--ly2eps           'lilypond' generates 'EPS' files directly (default)
--pdf2eps          'lilypond' generates a 'PDF' file that is transformed

-k|--keep_all      do not delete any temporary files
-v|--verbose       print much information to STDERR

Options with an argument:
-e|--eps_dir=...   use a directory for the EPS files
-o|--output=...    sent output in the groff language into file ...
-p|--prefix=...    start for the names of temporary files
-t|--temp_dir=...  provide the directory for temporary files.

The directories set are created when they do not exist.
*;

    # old options:
    # --keep_files       -k: do not delete any temporary files
    # --file_prefix=...  -p: start for the names of temporary files

    $main::stdout->print( $usage );
  } # end sub usage()


  sub version { # for '--version'
    our ( $Globals, $Legalese, $stdout, $Args );
    my $groff_version = '';
    if ( $Globals->{'groff_version'} ) {
      $groff_version = "(groff $Globals->{'groff_version'}) ";
    }

    my $output = EMPTYSTRING;
    $output = "$Globals->{'prog'} ${groff_version}version "
      .  $Legalese->{'version'};

    $stdout->print($output);
  } # end sub version()
}

#die "test: ";
########################################################################
# OOP declarations for some file handles
########################################################################

use integer;

########################################################################
# OOP for writing file handles that are open by default, like STD*
########################################################################

# -------------------------- _FH_WRITE_OPENED --------------------------

{	# FH_OPENED: base class for all opened file handles, like $TD*

  package _FH_WRITE_OPENED;
  use strict;

  sub new {
    my ( $pkg, $std ) = @_;
    bless {
	   'fh' => $std,
	  }
  }

  sub open {
  }

  sub close {
  }

  sub print {
    my $self = shift;
    for ( @_ ) {
      print { $self->{'fh'} } $_;
    }
  }

}


# ------------------------------ FH_STDOUT ----------------------------

{			     # FH_STDOUT: print to normal output STDOUT

  package FH_STDOUT;
  use strict;
  @FH_STDOUT::ISA = qw( _FH_WRITE_OPENED );

  sub new {
    &_FH_WRITE_OPENED::new( '_FH_WRITE_OPENED', *STDOUT );
  }

}				# end FH_STDOUT


# ------------------------------ FH_STDERR -----------------------------

{				# FH_STDERR: print to STDERR

  package FH_STDERR;
  use strict;
  @FH_STDERR::ISA = qw( _FH_WRITE_OPENED );

  sub new {
    &_FH_WRITE_OPENED::new( 'FH_OPENED', *STDERR );
  }

}				# end FH_STDERR


########################################################################
# OOP for file handles that write into a file or string
########################################################################

# ------------------------------- FH_FILE ------------------------------

{	       # FH_FILE: base class for writing into a file or string

  package FH_FILE;
  use strict;

  sub new {
    my ( $pkg, $file ) = @_;
    bless {
	   'fh' => undef,
	   'file' => $file,
	   'opened' => main::FALSE,
	  }
  }

  sub DESTROY {
    my $self = shift;
    $self->close();
  }

  sub open {
    my $self = shift;
    my $file = $self->{'file'};
    if ( $file && -e $file ) {
      die "file $file is not writable" unless ( -w $file );
      die "$file is a directory" if ( -d $file );
    }
    open $self->{'fh'}, ">", $self->{'file'}
      or die "could not open file '$file' for writing: $!";
    $self->{'opened'} = main::TRUE;
  }

  sub close {
    my $self = shift;
    close $self->{'fh'} if ( $self->{'opened'} );
    $self->{'opened'} = main::FALSE;
  }

  sub print {
    my $self = shift;
    $self->open() unless ( $self->{'opened'} );
    for ( @_ ) {
      print { $self->{'fh'} } $_;
    }
  }

}				# end FH_FILE


# ------------------------------ FH_STRING -----------------------------

{				# FH_STRING: write into a string

  package FH_STRING;		# write to \string
  use strict;
  @FH_STRING::ISA = qw( FH_FILE );

  sub new {
    my $pkg = shift;		# string is a reference to scalar
    bless
      {
       'fh' => undef,
       'string' => '',
       'opened' => main::FALSE,
      }
    }

  sub open {
    my $self = shift;
    open $self->{'fh'}, ">", \ $self->{'string'}
      or die "could not open string for writing: $!";
    $self->{'opened'} = main::TRUE;
  }

  sub get { # get string, move to array ref, close, and return array ref
    my $self = shift;
    return '' unless ( $self->{'opened'} );
    my $a = &string2array( $self->{'string'} );
    $self->close();
    return $a;
  }

}				# end FH_STRING


# -------------------------------- FH_NULL -----------------------------

{				# FH_NULL: write to null device

  package FH_NULL;
  use strict;
  @FH_NULL::ISA = qw( FH_FILE FH_STRING );

  use File::Spec;

  my $devnull = File::Spec->devnull();
  $devnull = '' unless ( -e $devnull && -w $devnull );

  sub new {
    my $pkg = shift;
    if ( $devnull ) {
      &FH_FILE::new( $pkg, $devnull );
    } else {
      &FH_STRING::new( $pkg );
    }
  } # end new()

}				# end FH_NULL


########################################################################
# OOP for reading file handles
########################################################################

# ---------------------------- FH_READ_FILE ----------------------------

{ # FH_READ_FILE: read a file

  package FH_READ_FILE;
  use strict;

  sub new {
    my ( $pkg, $file ) = @_;
    die "File '$file' cannot be read." unless ( -f $file && -r $file );
    bless {
	   'fh' => undef,
	   'file' => $file,
	   'opened' => main::FALSE,
	  }
  }

  sub DESTROY {
    my $self = shift;
    $self->close();
  }

  sub open {
    my $self = shift;
    my $file = $self->{'file'};
    if ( $file && -e $file ) {
      die "file $file is not writable" unless ( -r $file );
      die "$file is a directory" if ( -d $file );
    }
    open $self->{'fh'}, "<", $self->{'file'}
      or die "could not read file '$file': $!";
    $self->{'opened'} = main::TRUE;
  }

  sub close {
    my $self = shift;
    close $self->{'fh'} if ( $self->{'opened'} );
    $self->{'opened'} = main::FALSE;
  }

  sub read_line {
    # Read 1 line of the file into a chomped string.
    # Do not close the read handle at the end.
    my $self = shift;
    $self->open() unless ( $self->{'opened'} );

    my $res;
    if ( defined($res = CORE::readline($self->{'fh'}) ) ) {
      chomp $res;
      return $res;
    } else {
      $self->close();
      return undef;
    }
  }

  sub read_all {
    # Read the complete file into an array reference.
    # Close the read handle at the end.
    # Return array reference.
    my $self = shift;
    $self->open() unless ( $self->{'opened'} );

    my $res = [];
    my $line;
    while ( defined ( $line = CORE::readline $self->{'fh'} ) ) {
      chomp $line;
      push @$res, $line;
    }
    $self->close();
    $self->{'opened'} = main::FALSE;
    return $res;
  }

}

# end of OOP definitions


our $stdout = new FH_STDOUT();
our $stderr = new FH_STDERR();

# verbose printing, not clear whether this will be set by '--verbose',
# so store this now into a string, which can be gotten later on, when
# it will become either STDERR or /dev/null
our $v = new FH_STRING();

# for standard output, either STDOUT or output file
our $out;

# end of FH


########################################################################
# Args: command-line arguments
########################################################################

# command-line arguments are handled in 2 runs:
# 1) split short option collections, '=' optargs, and transfer abbrevs
# 2) handle the transferred options with subs

our $Args =
  {
   'eps_dir' => EMPTYSTRING, # can be overwritten by '--eps_dir'

   # 'eps-func' has 2 possible values:
   # 1) 'pdf' '--pdf2eps' (default)
   # 2) 'ly' from '--ly2eps'
   'eps_func' => 'pdf',

   # files names of temporary files start with this string,
   # can be overwritten by '--prefix'
   'prefix' => 'ly',

   # delete or do not delete temporary files
   'keep_all' => FALSE,

   # the roff output goes normally to STDOUT, can be a file with '--output'
   'output' => EMPTYSTRING,

   # temporary directory, can be overwritten by '--temp_dir',
   # empty for default of the program
   'temp_dir' => EMPTYSTRING,

   # regulates verbose output (on STDERR), overwritten by '--verbose'
   'verbose' => FALSE,
  };

{ # 'Args'
  use integer;

  our ( $Globals, $Args, $stderr, $v, $out );

  # ----------
  # subs for second run, for remaining long options after splitting and
  # transfer
  # ----------

  my %opts_with_arg =
    (

     '--eps_dir' => sub {
       $Args->{'eps_dir'} = shift;
     },

     '--output' => sub {
       $Args->{'output'} = shift;
     },

     '--prefix' => sub {
       $Args->{'prefix'} = shift;
     },

     '--temp_dir' => sub {
       $Args->{'temp_dir'} = shift;
     },

    );				# end of %opts_with_arg


  my %opts_noarg =
    (

     '--help' => sub {
       &usage;
       exit;
     },

     '--keep_all' => sub {
       $Args->{'keep_all'} = TRUE;
     },

     '--license' => sub {
       &license;
       exit;
     },

     '--ly2eps' => sub {
       $Args->{'eps_func'} = 'ly';
     },

     '--pdf2eps' => sub {
       $Args->{'eps_func'} = 'pdf';
     },

     '--verbose' => sub {
       $Args->{'verbose'} = TRUE;
     },

     '--version' => sub {
       &version;
       exit;
     },

    );				# end of %opts_noarg


  # used variables in both runs

  my @files = EMPTYARRAY;


  #----------
  # first run for command-line arguments
  #----------

  # global variables for first run

  my @splitted_args;
  my $double_minus = FALSE;
  my $arg = EMPTYSTRING;
  my $has_arg = FALSE;


  # Split short option collections and transfer these to suitable long
  # options from above.  Note that '-v' now means '--verbose' in version
  # 'v1.1', earlier versions had '--version' for '-v'.

  my %short_opts =
    (
     '?' => '--help',
     'e' => '--eps_dir',
     'h' => '--help',
     'l' => '--license',
     'k' => '--keep_all',
     'o' => '--output',
     'p' => '--prefix',
     't' => '--temp_dir',
     'v' => '--verbose',
     'V' => '--verbose',
    );


  # transfer long option abbreviations to the long options from above

  my @long_opts;

  $long_opts[3] =
    {				# option abbreviations of 3 characters
     '--e' => '--eps_dir',
     '--f' => '--prefix',		# --f for --file_prefix
     '--h' => '--help',
     '--k' => '--keep_all',	# and --keep_files
     '--o' => '--output',
     '--p' => '--prefix',		# and --file_prefix
     '--t' => '--temp_dir',
     '--u' => '--help',		# '--usage' is mapped to '--help'
    };

  $long_opts[4] =
    {				# option abbreviations of 4 characters
     '--li' => '--license',
     '--ly' => '--ly2eps',
     '--pd' => '--pdf2eps',
     '--pr' => '--prefix',
    };

  $long_opts[6] =
    {				# option abbreviations of 6 characters
     '--verb' => '--verbose',
     '--vers' => '--version',
    };


  # subs for short splitting and replacing long abbreviations

  my $split_short = sub {

    my @chars = split //, $1;	# omit leading dash

       # if result is TRUE: run 'next SPLIT' afterwards

     CHARS: while ( @chars ) {
	 my $c = shift @chars;

	 unless ( exists $short_opts{$c} ) {
	   $stderr->print( "Unknown short option '-$c'." );
	   next CHARS;
	 }

	 # short option exists

	 # map or transfer to special long option from above
	 my $transopt = $short_opts{$c};

	 if ( exists $opts_noarg{$transopt} ) {
	   push @splitted_args, $transopt;
	   $Args->{'verbose'}  = TRUE if ( $transopt eq '--verbose' );
	   next CHARS;
	 }

	 if ( exists $opts_with_arg{$transopt} ) {
	   push @splitted_args, $transopt;

	   if ( @chars ) {
	     # if @chars is not empty, option $transopt has argument
	     # in this arg, the rest of characters in @chars
	     push @splitted_args, join "", @chars;
	     @chars = EMPTYARRAY;
	     return TRUE;		# use 'next SPLIT' afterwards
	   }

	   # optarg is the next argument
	   $has_arg = $transopt;
	   return TRUE;		# use 'next SPLIT' afterwards
	 }			# end of if %opts_with_arg
       }				# end of while CHARS
       return FALSE;		# do not do anything
  };				# end of sub for short_opt_collection


  my $split_long = sub {
    my $from_arg = shift;
    $from_arg =~ /^([^=]+)/;
    my $opt_part = lc($1);
    my $optarg = undef;
    if ( $from_arg =~ /=(.*)$/ ) {
      $optarg = $1;
    }

   N: for my $n ( qw/6 4 3/ ) {
      $opt_part =~ / # match $n characters
		     ^
		     (
		       .{$n}
		     )
		   /x;
      my $argn = $1;		# get the first $n characters

      # no match, so luck for fewer number of chars
      next N unless ( $argn );

      next N unless ( exists $long_opts[$n]->{$argn} );
      # not in $n hash, so go on to next loop for $n

      # now $n-hash has arg

      # map or transfer to special long opt from above
      my $transopt = $long_opts[$n]->{$argn};

      # test on option without arg
      if ( exists $opts_noarg{$transopt} ) { # opt has no arg
	$stderr->print( 'Option ' . $transopt . 'has no argument: ' .
			$from_arg . '.' ) if ( defined($optarg) );
	push @splitted_args, $transopt;
	$Args->{'verbose'} = TRUE if ( $transopt eq '--verbose' );
	return TRUE;		# use 'next SPLIT' afterwards
      }				# end of if %opts_noarg

      # test on option with arg
      if ( exists $opts_with_arg{$transopt} ) { # opt has arg
	push @splitted_args, $transopt;

	# test on optarg in arg
	if ( defined($optarg) ) {
	  push @splitted_args, $1;
	  return TRUE; # use 'next SPLIT' afterwards
	} # end of if optarg in arg

	# has optarg in next arg
	$has_arg = $transopt;
	return TRUE; # use 'next SPLIT' afterwards
      } # end of if %opts_with_arg

      # not with and without option, so is not permitted
      $stderr->print( "'" . $transopt .
		      "' is unknown long option from '" . $from_arg . "'" );
      return TRUE; # use 'next SPLIT' afterwards
    } # end of for N
    return FALSE; # do nothing
  }; # end of split_long()


  #----------
  # do split and transfer arguments
  #----------
  sub run_first {

   SPLIT: foreach (@ARGV) {
      # Transform long and short options into some given long options.
      # Split long opts with arg into 2 args (no '=').
      # Transform short option collections into given long options.
      chomp;

      if ( $has_arg ) {
	push @splitted_args, $_;
	$has_arg = EMPTYSTRING;
	next SPLIT;
      }

      if ( $double_minus ) {
	push @files, $_;
	next SPLIT;
      }

      if ( $_ eq '-' ) {		# file arg '-'
	push @files, $_;
	next SPLIT;
      }

      if ( $_ eq '--' ) {		# POSIX arg '--'
	push @splitted_args, $_;
	$double_minus = TRUE;
	next SPLIT;
      }

      if ( / # short option or collection of short options
	     ^
	     -
	     (
	       [^-]
	       .*
	     )
	     $
	   /x ) {
	$split_short->($1);
	next SPLIT;
      }				# end of short option

      if ( /^--/ ) {		# starts with 2 dashes, a long option
	$split_long->($_);
	next SPLIT;
      }				# end of long option

      # unknown option without leading dash is a file name
      push @files, $_;
      next SPLIT;
    }				# end of foreach SPLIT

				  # all args are considered
    $stderr->print( "Option '$has_arg' needs an argument." )
      if ( $has_arg );


    push @files, '-' unless ( @files );
    @ARGV = @splitted_args;

  };		    # end of first run, splitting with map or transfer


  #----------
  # open or ignore verbose output
  #----------
  sub install_verbose {
    if ( $Args->{'verbose'} ) { # '--verbose' was used
      # make verbose output into $v
      # get content of string so far as array ref, close
      my $s = $v->get();

      $v = new FH_STDERR(); # make verbose output into STDERR
      if ( $s ) {
	for ( @$s ) {
	  # print the file content into new verbose output
	  $v->print($_);
	}
      }
      # verbose output is now active (into STDERR)
      $v->print( "Option '-v' means '--verbose'." );
      $v->print( "Version information is printed by option"
	         . " '--version'."
      );
      $v->print( "#" x 72 );

    } else { # '--verbose' was not used
      # do not be verbose, make verbose invisible

      $v->close(); # close and ignore the string content

      $v = new FH_NULL();
      # this is either into /dev/null or in an ignored string

    } # end if-else about verbose
    # '$v->print' works now in any case

    $v->print( "Verbose output was chosen." );

    my $s = $Globals->{'prog_is_installed'} ? '' : ' not';
    $v->print( $Globals->{'prog'} . " is" . $s .
	       " installed." );

    $v->print( 'The command-line options are:' );

    $s = "  options:";
    $s .= " '" . $_ . "'" for ( @ARGV );
    $v->print( $s );

    $s = "  file names:";
    $s .= " '" . $_ . "'\n" for ( @files );
    $v->print( $s );
  } # end install_verbose()


  #----------
  # second run of command-line arguments
  #----------
  sub run_second {
      # Second run of args with new @ARGV from the former splitting.
      # Arguments are now split and transformed into special long
      # options.

      my $double_minus = FALSE;
      my $has_arg = FALSE;

    ARGS: for my $arg ( @ARGV ) {

	# ignore '--', file names are handled later on
	last ARGS if ( $arg eq '--' );

	if ( $has_arg ) {
	  unless ( exists $opts_with_arg{$has_arg} ) {
	    $stderr->print( "'\%opts_with_args' does not have key '" .
			      $has_arg . "'." );
	    next ARGS;
	  }

	  $opts_with_arg{$has_arg}->($arg);
	  $has_arg = FALSE;
	  next ARGS;
	} # end of $has_arg

	if ( exists $opts_with_arg{$arg} ) {
	  $has_arg = $arg;
	  next ARGS;
	}

	if ( exists $opts_noarg{$arg} ) {
	  $opts_noarg{$arg}->();
	  next ARGS;
	}

	# not a suitable option
	$stderr->print( "Wrong option '" . $arg . "'." );
	next ARGS;

      } # end of for ARGS:


      if ( $has_arg ) { # after last argument
	die "Option '$has_arg' needs an argument.";
      }

    }; # end of second run


  sub handle_args {
    # handling the output of args

    if ( $Args->{'output'} ) { # '--output' was set in the arguments
      my $out_path = &path2abs($Args->{'output'});
      die "Output file name $Args->{'output'} cannot be used."
	unless ( $out_path );

      my ( $file, $dir );
      ( $file, $dir ) = File::Basename::fileparse($out_path)
	or die "Could not handle output file path '" . $out_path
	  . "': directory name '" . $dir . "' and file name '" . $file
	  . "'.";

      die "Could not find output directory for '" . $Args->{'output'}
        . "'" unless ( $dir );
      die "Could not find output file: '" . $Args->{'output'} .
	"'" unless ( $file );

      if ( -d $dir ) {
	die "Could not write to output directory '" . $dir . "'."
	  unless ( -w $dir );
      } else {
	$dir = &make_dir($dir);
	die "Could not create output directory in: '" . $out_path . "'."
	  unless ( $dir );
      }

      # now $dir is a writable directory

      if ( -e $out_path ) {
	die "Could not write to output file '" . $out_path . "'."
	  unless ( -w $out_path );
      }

      $out = new FH_FILE( $out_path );
      $v->print( "Output goes to file '" . $out_path . "'." );
    } else { # '--output' was not set
      $out = new FH_STDOUT();
    }
    # no $out is the right behavior for standard output

  #  $Args->{'prefix'} .= '_' . $Args->{'eps_func'} . '2eps';

    @ARGV = @files;
  }

  &run_first();
  &install_verbose();
  &run_second();
  &handle_args();
}

# end 'Args'


########################################################################
# temporary directory .../tmp/groff/USER/lilypond/TIME
########################################################################

our $Temp =
  {
   # store the current directory
   'cwd' => Cwd::getcwd(),

   # directory for EPS files
   'eps_dir' => EMPTYSTRING,

   # temporary directory
   'temp_dir' => EMPTYSTRING,
  };

{ # 'Temp'

  if ( $Args->{'temp_dir'} ) {

    #----------
    # temporary directory was set by '--temp_dir'
    #----------

    my $dir = $Args->{'temp_dir'};

    $dir = &path2abs($dir);
    $dir = &make_dir($dir) or
      die "The directory '$dir' cannot be used temporarily: $!";


    # now '$dir' is a writable directory

    opendir( my $dh, $dir ) or
      die "Could not open temporary directory '$dir': $!";
    my $file_name;
    my $found = FALSE;
    my $prefix = $Args->{'prefix'};
    my $re = qr<
		 ^
		 $prefix
		 _
	       >x;

  READDIR: while ( defined($file_name = readdir($dh)) ) {
      chomp $file_name;
      if ( $file_name =~ /$re/ ) { # file name starts with $prefix_
	$found = TRUE;
	last READDIR;
      }
      next;
    }

    $Temp->{'temp_dir'} = $dir;
    my $n = 0;
    while ( $found ) {
      $dir = File::Spec->catdir( $Temp->{'temp_dir'}, ++$n );
      next if ( -e $dir );

      $dir = &make_dir($dir) or next;

      $found = FALSE;
      last;
    }

    $Temp->{'temp_dir'} = $dir;


  } else { # $Args->{'temp_dir'} not given by '--temp_dir'

    #----------
    # temporary directory was not set
    #----------

    { # search for or create a temporary directory

      my @tempdirs = EMPTYARRAY;
      {
	my $tmpdir = File::Spec->tmpdir();
	push @tempdirs, $tmpdir
	  if ( $tmpdir && -d $tmpdir && -w $tmpdir );

	my $root_dir = File::Spec->rootdir(); # '/' in Unix
	my $root_tmp = File::Spec->catdir($root_dir, 'tmp');
	push @tempdirs, $root_tmp
	  if ( $root_tmp ne $tmpdir && -d $root_tmp && -w $root_tmp );

	# home directory of the actual user
	my $home = File::HomeDir->my_home;
	my $home_tmp = File::Spec->catdir($home, 'tmp');
	push @tempdirs, $home_tmp if ( -d $home_tmp && -w $home_tmp );

	# '/var/tmp' in Unix
	my $var_tmp = File::Spec->catdir('', 'var', 'tmp');
	push @tempdirs, $var_tmp if ( -d $var_tmp && -w $var_tmp );
      }


      my @path_extension = qw( groff ); # TEMPDIR/groff/USER/lilypond/N
      {
	# '$<' is UID of actual user,
	# 'getpwuid' gets user name in scalar context
	my $user = getpwuid($<);
	push @path_extension, $user if ( $user );

	push @path_extension, qw( lilypond );
      }


    TEMPS: foreach ( @tempdirs ) {

	my $dir; # final directory name in 'while' loop
	$dir = &path2abs($_);
	next TEMPS unless ( $dir );

	# beginning of directory name
	my @dir_begin =
	  ( File::Spec->splitdir($dir), @path_extension );


	my $n = 0;
	my $dir_blocked = TRUE;
      BLOCK: while ( $dir_blocked ) {
	  # should become the final dir name
	  $dir = File::Spec->catdir(@dir_begin, ++$n);
	  next BLOCK if ( -d $dir );

	  # dir name is now free, create it, and end the blocking
	  my $res = &make_dir( $dir );
	  die "Could not create directory: $dir" unless ( $res );

	  $dir = $res;
	  $dir_blocked = FALSE;
	}

	next TEMPS unless ( -d $dir && -w $dir  );

	# $dir is now a writable directory
	$Temp->{'temp_dir'} = $dir; # tmp/groff/USER/lilypond/TIME
	last TEMPS;
      } # end foreach tmp directories
    } # end to create a temporary directory

    die "Could not find a temporary directory" unless
      ( $Temp->{'temp_dir'} && -d $Temp->{'temp_dir'} &&
	-w $Temp->{'temp_dir'} );

  } # end temporary directory

  $v->print( "Temporary directory: '" . $Temp->{'temp_dir'} . "'\n" );
  $v->print( "file_prefix: '" . $Args->{'prefix'} . "'" );


  #----------
  # EPS directory
  #----------

  my $make_dir = FALSE;
  if ( $Args->{'eps_dir'} ) { # set by '--eps_dir'
    my $dir = $Args->{'eps_dir'};

    $dir = &path2abs($dir);

    if ( -e $dir ) {
      goto EMPTY unless ( -w $dir );

      # '$dir' is writable
      if ( -d $dir ) {
	my $upper_dir = $dir;

	my $found = FALSE;
	opendir( my $dh, $upper_dir ) or $found = TRUE;
	my $prefix = $Args->{'prefix'};
	my $re = qr<
		     ^
		     $prefix
		     _
		   >x;
	while ( not $found ) {
	  my $file_name = readdir($dh);
	  if ( $file_name =~ /$re/ ) { # file name starts with $prefix_
	    $found = TRUE;
	    last;
	  }
	  next;
	}

	my $n = 0;
	while ( $found ) {
	  $dir = File::Spec->catdir($upper_dir, ++$n);
	  next if ( -d $dir );
	  $found = FALSE;
	}
	$make_dir = TRUE;
	$Temp->{'eps_dir'} = $dir;
      } else { # '$dir' is not a dir, so unlink it to create it as dir
	if ( unlink $dir ) { # could remove '$dir'
	  $Temp->{'eps_dir'} = $dir;
	  $make_dir = TRUE;
	} else { # could not remove
	  $stderr->print( "Could not use EPS dir '" . $dir .
			  "', use temp dir." );
	} # end of unlink
      } # end test of -d $dir
    } else {
      $make_dir = TRUE;
    } # end of if -e $dir


    if ( $make_dir ) { # make directory '$dir'
      my $made = FALSE;
      $dir = &make_dir($dir) and $made = TRUE;

      if ( $made ) {
	$Temp->{'eps_dir'} = $dir;
	$v->print( "Directory for useful EPS files is '" . $dir . "'." );
      } else {
	$v->print( "The EPS directory '" . $dir . "' cannot be used: $!" );
      }
    } else { # '--eps_dir' was not set, so take the temporary directory
      $Temp->{'eps_dir'} = $Args->{'temp_dir'};
    } # end of make dir
  }

 EMPTY: unless ( $Temp->{'eps_dir'} ) {
    # EPS-dir not set or available, use temp dir,
    # but leave $Temp->{'}eps_dir'} empty
    $v->print( "Directory for useful EPS files is the " .
      "temporary directory '" . $Temp->{'temp_dir'} . "'." );
  }

} # end 'Temp'


########################################################################
# Read: read files or stdin
########################################################################

our $Read =
  {
   'file_numbered' => EMPTYSTRING,
   'file_ly' => EMPTYSTRING, # '$file_numbered.ly'
  };

{ # read files or stdin

  my $ly_number = 0; # number of lilypond file

  # '$Args->{'prefix'}_[0-9]'

  my $lilypond_mode = FALSE;

  my $arg1; # first argument for '.lilypond'
  my $arg2; # argument for '.lilypond include'

  my $path_ly; # path of ly-file


  my $check_file = sub { # for argument of '.lilypond include'
    my $file = shift; # argument is a file name
    $file = &path2abs($file);
    unless ( $file ) {
      die "Line '.lilypond include' without argument";
      return '';
    }
    unless ( -f $file && -r $file ) {
      die "Argument '$file' in '.lilypond include' is not a readable file";
    }

    return $file;
  }; # end sub &$check_file()


  my $increase_ly_number = sub {
    ++$ly_number;
    $Read->{'file_numbered'} = $Args->{'prefix'} . '_' . $ly_number;
    $Read->{'file_ly'} =  $Read->{'file_numbered'} . '.ly';
    $path_ly = File::Spec->catdir($Temp->{'temp_dir'}, $Read->{'file_ly'} );
  };


  my %eps_subs =
    (
     'ly' => \&create_ly2eps,   # lilypond creates EPS files
     'pdf' => \&create_pdf2eps, # lilypond creates PDF file
    );

  # about lines starting with '.lilypond'

  my $ly;
  my $fh_include_file;
  my %lilypond_args =
    (

     'start' => sub {
       $v->print( "\nline: '.lilypond start'" );
       die "Line '.lilypond stop' expected." if ( $lilypond_mode );

       $lilypond_mode = TRUE;
       &$increase_ly_number;

       $v->print( "ly-file: '" . $path_ly . "'" );

       $ly = new FH_FILE($path_ly);
     },


     'end' => sub {
       $v->print( "line: '.lilypond end'\n" );
       die "Expected line '.lilypond start'." unless ( $lilypond_mode );

       $lilypond_mode = FALSE;
       $ly->close();

       if ( exists $eps_subs{ $Args->{'eps_func'} } ) {
	 $eps_subs{ $Args->{'eps_func'} }->();
       } else {
	 die "Wrong argument for \%eps_subs: " . $Args->{'eps_func'} . "'";
       }
     },


     'include' => sub { # '.lilypond include file...'

       # this may not be used within lilypond mode
       next LILYPOND if ( $lilypond_mode );

       my $file_arg = shift;

       my $file = &$check_file($file_arg);
       next LILYPOND unless ( $file );
       # file can be read now


       # '$fh_write_ly' must be opened
       &$increase_ly_number;

       $ly = new FH_FILE($path_ly);

       my $include = new FH_READ_FILE($file);
       my $res = $include->read_all(); # is a reference to an array
       foreach ( @$res ) {
	 chomp;
	 $ly->print($_);
       }
       $ly->close();

       if ( exists $eps_subs{ $Args->{'eps_func'} } ) {
	 $eps_subs{ $Args->{'eps_func'} }->();
       } else {
	 die "Wrong argument for \$eps_subs: '" . $Args->{'eps_func'} . "'";
       }
     }, # end '.lilypond include'

    ); # end definition %lilypond_args


 LILYPOND: foreach my $filename (@ARGV) {
    my $input;
    if ($filename eq '-') {
      $input = \*STDIN;
    } elsif (not open $input, '<', $filename) {
      warn $!;
      next;
    }
    while (<$input>) {
      chomp;
      my $line = $_;


      # now the lines with '.lilypond ...'

      if ( /
	     ^
	     [.']
	     \s*
	     lilypond
	     (
	       .*
	     )
	     $
	   /x ) { # .lilypond ...
	my $args = $1;
	$args =~ s/
		    ^
		    \s*
		  //x;
	$args =~ s/
		    \s*
		    $
		  //x;
	$args =~ s/
		    ^
		    (
		      \S*
		    )
		    \s*
		  //x;
	my $arg1 = $1; # 'start', 'end' or 'include'
	$args =~ s/["'`]//g;
	my $arg2 = $args; # file argument for '.lilypond include'

	if ( exists $lilypond_args{$arg1} ) {
	  $lilypond_args{$arg1}->($arg2);
	  next;
	} else {
	  # not a suitable argument of '.lilypond'
	  $stderr->print( "Unknown command: '$arg1' '$arg2':  '$line'" );
	}

	next LILYPOND;
      } # end if for .lilypond


      if ( $lilypond_mode ) { # do lilypond-mode
	# see '.lilypond start'
	$ly->print( $line );
	next LILYPOND;
      } # do lilypond-mode

      # unknown line without lilypond
      unless ( /
		 ^
		 [.']
		 \s*
		 lilypond
	       /x ) { # not a '.lilypond' line
	$out->print($line);
	next LILYPOND;
      }
    } # end while <$input>
  } # end foreach $filename
} # end Read


########################################################################
# clean up
########################################################################

END {

  exit unless ( defined($Temp->{'temp_dir'}) );

  if ( $Args->{'keep_all'} ) {
    # With --keep_all, no temporary files are removed.
    $v->print( "keep_all: 'TRUE'" );
    $v->print( "No temporary files will be deleted:" );

    opendir my $dh_temp, $Temp->{'temp_dir'} or
      die "Cannot open " . $Temp->{'temp_dir'} . ": $!";
    for ( sort readdir $dh_temp ) {
      next if ( /         # omit files starting with a dot
		  ^
		  \.
		/x );
      if ( /
	     ^
	     $Args->{'prefix'}
	     _
	   /x ) {
	my $file = File::Spec->catfile( $Temp->{'temp_dir'}, $_ );
	$v->print( "- " . $file );
	next;
      }
      next;
    } # end for sort readdir
    closedir $dh_temp;

  } else { # keep_all is not set
    # Remove all temporary files except the eps files.

    $v->print( "keep_all: 'FALSE'" );
    $v->print( "All temporary files except *.eps will be deleted" );


    if ( $Temp->{'eps_dir'} ) {
      # EPS files are in another dir, remove temp dir

      if ( &is_subdir( $Temp->{'eps_dir'}, $Temp->{'temp_dir'} ) ) {
	$v->print( "EPS dir is subdir of temp dir, so keep both." );
      } else { # remove temp dir
	$v->print( "Try to remove temporary directory '" .
	  $Temp->{'temp_dir'} ."':" );
	if ( File::Path::remove_tree($Temp->{'temp_dir'}) ) {
	  # remove succeeds
	  $v->print( "...done." );
	} else { # did not remove
	  $v->print( "Failure to remove temporary directory." );
	} # end test on remove
      } # end is subdir

    } else { # no EPS dir, so keep EPS files

      opendir my $dh_temp, $Temp->{'temp_dir'} or
	die "Cannot open " . $Temp->{'temp_dir'} . ": $!";
      for ( sort readdir $dh_temp ) {
	next if ( /          # omit files starting with a dot
		    ^
		    \.
		  /x );
	next if ( /          # omit EPS-files
		    \.eps
		    $
		  /x );
	if ( /
	       ^
	       $Args->{'prefix'}
	       _
	     /x ) { # this includes 'PREFIX_temp*'
	  my $file = File::Spec->catfile( $Temp->{'temp_dir'},  $_ );
	  $v->print( "Remove '" . $file . "'" );
	  unlink $file or $stderr->print( "Could not remove '$file': $!" );
	  next;
	} # end if prefix
	next;
      } # end for readdir temp dir
      closedir $dh_temp;
    } # end if-else EPS files
  } # end if-else keep files


  if ( $Temp->{'eps_dir'} ) {
    # EPS files in $Temp->{'eps_dir'} are always kept
    $v->print( "As EPS directory is set as '" .
      $Temp->{'eps_dir'} . "', no EPS files there will be deleted." );

    opendir my $dh_temp, $Temp->{'eps_dir'} or
      die "Cannot open '" . $Temp->{'eps_dir'} . ": $!";
    for ( sort readdir $dh_temp ) {
      next if ( /         # omit files starting with a dot
		  ^
		  \.
		/x );
      if ( /
	     ^
	     $Args->{'prefix'}
	     _
	     .*
	     \.eps
	     $
	   /x ) {
	my $file = File::Spec->catfile( $Temp->{'eps_dir'}, $_ );
	$v->print( "- " . $file );
	next;
      } # end if *.eps
      next;
    } # end for sort readdir
    closedir $dh_temp;

  }

  1;
} # end package Clean


1;
# Local Variables:
# fill-column: 72
# mode: CPerl
# End:
# vim: set autoindent textwidth=72:
