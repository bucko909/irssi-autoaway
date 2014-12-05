# $Id: away.pl,v 1.6 2003/02/25 08:48:56 nemesis Exp $

use Irssi 20100403.1617 ();
$VERSION = "0.1";
%IRSSI = (
	authors     => 'Jean-Yves Lefort, Larry "Vizzie" Daffner, Kees Cook, David Buckley',
	contact     => 'jylefort@brutele.be, vizzie@airmail.net, kc@outflux.net, davidwantsnomail',
	name        => 'away',
	description => 'Away with reason, unaway, and autoaway',
	license     => 'BSD',
	changed     => '$Date: 2010/05/04 15:51:02 $ ',
);

# /SET
#
#	away_reason		if you are not away and type /AWAY without
#				arguments, this string will be used as
#				your away reason
#
#       autoaway                number of seconds before marking away,
#                               only actions listed in "autounaway_level"
#                               will reset the timeout.
#
# changes:
#	2010
#		Changed autoaway to work by statting terminal.
#
#       2003-02-24
#                       0.23?
#                       merged with autoaway script
#
#	2003-01-09	release 0.22
#			* command char independed
#
#	2002-07-04	release 0.21
#			* signal_add's uses a reference instead of a string
#
# todo:
#
#	* rewrite the away command to support -one and -all switches
#       * make auto-away reason configurable
#
# (c) 2003 Jean-Yves Lefort (jylefort@brutele.be)
#
# (c) 2000 Larry Daffner (vizzie@airmail.net)
#     You may freely use, modify and distribute this script, as long as
#      1) you leave this notice intact
#      2) you don't pretend my code is yours
#      3) you don't pretend your code is mine
#
# (c) 2003 Kees Cook (kc@outflux.net)
#      merged 'autoaway.pl' and 'away.pl'
#
# (c) 2010 David Buckley
#      I don't really care what you do with my changes provided I'm not liable.

use strict;
use Irssi;
use Irssi::Irc;			# for DCC object

our ($autoaway_sec, $autoaway_to_tag, $monitor_timer, $am_away, $set_away, $last_act);

our $term = readlink('/proc/self/fd/0');
monitor_timer();

sub set_away {
	my $msg = $_[0] || Irssi::settings_get_str("away_reason");
	$_->send_raw("AWAY :$msg") for Irssi::servers();
	$am_away = 1;
}

sub set_back {
	$_->send_raw("AWAY") for Irssi::servers();
	undef $am_away;
}

sub cmd_away {
	my ($args, $server, $item) = @_;

	$server ||= do {
		my @servers = Irssi::servers();
		$servers[0];
	};

	# stop autoaway
	if (defined $autoaway_to_tag) {
		Irssi::timeout_remove($autoaway_to_tag);
		undef $autoaway_to_tag;
	}

	# stop autoback
	$set_away = 1;

	set_away($args);
}

sub cmd_back {
	my ($args, $server, $item) = @_;

	$server ||= do {
		my @servers = Irssi::servers();
		$servers[0];
	};

	undef $set_away;

	set_back();
}

sub has_activity {
	return if $set_away;
	my $server = do {
		my @servers = Irssi::servers();
		$servers[0];
	};

	if ($am_away) {
		# come back from away
		set_back();
	} else {
		# bump the autoaway timeout
		reset_timer();
	}
}

sub away_setupcheck {
	$autoaway_sec = Irssi::settings_get_int("autoaway");
	reset_timer();
}

sub auto_timeout {
	my ($data, $server) = @_;
	my $msg = "Auto-away after $autoaway_sec seconds";

	Irssi::timeout_remove($autoaway_to_tag);
	undef $autoaway_to_tag;

	Irssi::print($msg);

	my (@servers) = Irssi::servers();
	set_away("$msg");
}

sub monitor_timer {
	if (defined($monitor_timer)) {
		Irssi::timeout_remove($monitor_timer);
		undef $monitor_timer;
	}
	my $act = (stat($term))[8];
	if ($last_act) {
		has_activity() if $act > $last_act;
	}
	$last_act = $act;
	$monitor_timer = Irssi::timeout_add(1000, "monitor_timer", "");
}

sub reset_timer {
	if (defined($autoaway_to_tag)) {
		Irssi::timeout_remove($autoaway_to_tag);
		undef $autoaway_to_tag;
	}
	if ($autoaway_sec) {
		$autoaway_to_tag = Irssi::timeout_add($autoaway_sec*1000, "auto_timeout", "");
	}
}

Irssi::settings_add_str("misc", "away_reason", "not here");
Irssi::settings_add_int("misc", "autoaway", 0);

Irssi::signal_add("setup changed" => \&away_setupcheck);

Irssi::command_bind("away", "cmd_away");
Irssi::command_bind("back", "cmd_back");

away_setupcheck();
