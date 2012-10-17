package P9Y::ProcessTable;

# VERSION
# ABSTRACT: Portably access the process table

use sanity;

use Path::Class;
use namespace::clean;

BEGIN {
   # Figure out which OS module we should use
   for (lc $^O) {
      when (/mswin32|cygwin/) {
         require P9Y::ProcessTable::Win32;
      }
      # BSD::Process currently only supports FreeBSD;
      # fall by on /proc for the others
      when ('freebsd') {
         require P9Y::ProcessTable::BSD;
      }
      when ('darwin') {
         require P9Y::ProcessTable::Darwin;
      }
      when ('os2') {
         require P9Y::ProcessTable::OS2;
      }
      when ('vms') {
         require P9Y::ProcessTable::VMS;
      }
      when ('dos') {
         die "Heh, DOS processes... you're funny!";
      }
      default {
         # let's hope they have /proc
         if ( -d dir('', 'proc') ) {
            require P9Y::ProcessTable::ProcFS;
         }
         else {
            die "No idea how to handle $^O processes.  Email me with more information!";
         }
      }
   }
}

#############################################################################
# Common Methods (may potentially be redefined with OS-specific ones)

no warnings 'redefine';

sub table {
   my $self = shift;
   return map { $self->process($_) } ($self->list);
}

sub process {
   my ($self, $pid) = @_;
   $pid = $$ if (@_ == 1);
   my $hash = $self->_process_hash($pid);
   return unless $hash;
   
   $hash->{_pt_obj} = $self;
   return P9Y::ProcessTable::Process->new($hash);
}

42;

__END__

=begin wikidoc

= SYNOPSIS

   use P9Y::ProcessTable;
   
   my @process_table = P9Y::ProcessTable->table;
   print $process_table[0]->pid."\n";
   
   my @pids = P9Y::ProcessTable->list;
   
   my $perl_process  = P9Y::ProcessTable->process;
   my $other_process = P9Y::ProcessTable->process($pid);
   
   if ($other_process->has_threads) {
      print "# of Threads: ".$other_process->threads."\n";
      sleep 2;
      $other_process->refresh;
      print "# of Threads: ".$other_process->threads."\n";
   }

   # A cheap and sleazy version of ps
   my $FORMAT = "%-6s %-10s %-8s %-24s %s\n";
   printf($FORMAT, "PID", "TTY", "STAT", "START", "COMMAND");
   foreach my $p ( P9Y::ProcessTable->table ) {
      printf($FORMAT,
         $p->pid,
         $p->ttydev,
         $p->state,
         scalar(localtime($p->start)),
         $p->cmdline,
      );
   }
   
   # Dump all the information in the current process table
   no strict 'refs';
   foreach my $p ( P9Y::ProcessTable->table ) {
      print "--------------------------------\n";
      foreach my $f (P9Y::ProcessTable->fields) {
         my $has_f = 'has_'.$f;
         print $f, ":  ", $p->$f(), "\n" if ( $p->$has_f() );
      }
   }
   
= DESCRIPTION

This interface will portably access the process table, no matter what the OS, and normalize its outputs to work similar across all platforms.

= METHODS

All methods to this module are actually class-based (objectless) calls.  However, the [P9Y::ProcessTable::Process] returns are actual objects.

== fields

Returns a list of the field names supported by the module on the current architecture.

== list

Returns a list of PIDs that are available in the process table.  On most systems, this is a less heavy call than {table}, as it doesn't have to
look up the information for every single process.

== table

Returns a list of [P9Y::ProcessTable::Process] objects for all of the processes in the process table.  (More information in that module POD.)

== process

Returns a [P9Y::ProcessTable::Process] object for the process specified.  If a process isn't specified, it will look up {$$} (or its platform
equivalent).

= P9Y?

Portability.  You know, like I18N and L10N.

= SUPPORTED PLATFORMS

Currently, this module supports:

* All {/proc} friendly OSs to some degree.  Linux and Solaris are fully supported so far.
* Windows (most flavors)
* Darwin (see CAVEATS)
* FreeBSD (only; see CAVEATS)
* OS/2 (hey, the module was there...)
* VMS (same here; probably needs some testing)

= HISTORY

This module spawned because [Proc::ProcessTable] has fallen into [bugland|http://matrix.cpantesters.org/?dist=Proc-ProcessTable-0.45] for the
last 4 years, and many people just want to be able to get a simple {PID+cmdline} from the process table.  While this module offers more than
that as a bonus, the goal of this module is to have something that JFW, and continues to JFW.

With that in mind, here my list of what went wrong with [Proc::ProcessTable].  I have nothing against the authors of that module, but I feel like
we should try to learn from our failures and adapt in kind.

* *Too many OSs in one distribution.*  I dunno about you, but I don't happen to have 15 different OSs on VMs anywhere.  At best, I might have 
access to 2-3 different platforms.  So, trying to test out code on a platform that you don't actually own is especially difficult.

Thus, this module is merely a wrapper around various other modules that provide process table information.  Those guys actually have the means
(and the drive) to test their stuff on those OSs.  (The sole exception is the ProcFS module, but that may get split eventually.)

* *Too much C/XS code.*  The C and XS code falls in a class of exclusivity that makes it even harder to maintain.  If I were to conjure up some
wild guess, I would say that only 20% of Perl programmers could actually read, understand, and program C/XS code.  People aren't calling the
process table a 1000 times a second, so there's really no need for a speed boost, either.

Alas, sometimes this is unavoidable, with the process information buried in C library calls.  However, the {/proc} FS is available on a great
many amount of UNIX platforms, so it should be used ~as much as possible~.  Also, I take this moment to shake my tiny little fist at the BSD
folks for actually *regressing* the OS by removing support for {/proc}.  All of the reasons behind it are unsound or have solutions that don't
involve removing this most basic right of UNIX users.

= CAVEATS / TODO

* No support for any non-proc BSD system other than FreeBSD.  This is because [BSD::Process] only supports FreeBSD.  If the support is needed,
bug that module maintainer and provide some patches.  Then bug me and I'll change the OS detection logic.

* This thing actually uses [Proc::ProcessTable] for Darwin/OSX systems.  Darwin doesn't have a {/proc} access point (BSD... sigh).  Fortunately,
P:PT is passing all Darwin tests (so far), so until somebody splits the code from that to a new module (hint hint)...

* Certain other {/proc} friendly OSs needs further support.  Frankly, I'm trying to get a feel for what people actually need than just spending 
the time coding something for, say, NeXT OS and 50 other flavors.  However, supporting one OS or another should be pretty easy.  If you need
support, dive into the {ProcFS} code and submit a patch.

* See [P9Y::ProcessTable::Process] for other caveats.

= SEE ALSO

* [Proc::ProcessTable]
* [BSD::Process]
* [Win32::Process]
* [OS2::Process]
* [VMS::Process]

=end wikidoc
