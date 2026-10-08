#!/usr/bin/env bash
# unattended-dev v8.9: runs a command with a time limit (macOS has no
# timeout). The command gets its own process group, and the whole group is
# stopped (TERM, then KILL 5 s later) when the time runs out, when this
# script is interrupted and when the command ends, so nothing it started is
# left running (or holding a pipe open).
#
# Usage: .desatendido/con-limite.sh <seconds> -- <command...>
#
# Exit: the command's own code; 124 if it ran out of time; 128+N if it was
# killed by signal N (never 0).
set -u
limit="${1:-}"; sep="${2:-}"
case "$limit" in ''|*[!0-9]*) echo "con-limite: <seconds> -- <command...>" >&2; exit 2;; esac
[ "$sep" = "--" ] && [ $# -gt 2 ] || { echo "con-limite: <seconds> -- <command...>" >&2; exit 2; }
shift 2
[ "$limit" -ge 1 ] || limit=1

exec perl -e '
  use POSIX ":sys_wait_h";
  my $t = shift;
  my $pid = fork();
  die "con-limite: fork failed: $!\n" unless defined $pid;
  if ($pid == 0) { setpgrp(0, 0); exec @ARGV or exit 127; }
  sub end_group { # TERM to the whole group, then KILL to what is left
    kill "TERM", -$pid;
    for (1 .. 50) { waitpid($pid, WNOHANG); last unless kill(0, -$pid); select(undef, undef, undef, 0.1); }
    kill "KILL", -$pid;
  }
  sub stop { my $code = shift; end_group(); exit $code; }
  $SIG{ALRM} = sub { stop(124) };
  $SIG{INT}  = sub { stop(130) };
  $SIG{TERM} = sub { stop(143) };
  $SIG{HUP}  = sub { stop(129) };
  alarm $t;
  waitpid($pid, 0); my $s = $?; alarm 0;
  end_group(); # what the command left in the background ends with it
  exit(128 + ($s & 127)) if ($s & 127);
  exit($s >> 8);
' "$limit" "$@"
