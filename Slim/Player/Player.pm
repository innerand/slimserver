package Slim::Player::Player;

# SlimServer Copyright (c) 2001-2004 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# $Id$
#

use strict;
use Slim::Player::Client;
use Slim::Utils::Misc;
use Slim::Display::VFD::Animation;
use Slim::Hardware::IR;

use base qw(Slim::Player::Client);

our @fonttable = ( ['small', 'small'], [ undef, 'large']);

our $defaultPrefs = {
		'autobrightness'		=> 1
		,'bass'					=> 50
		,'digitalVolumeControl'	=> 1
		,'disabledirsets'		=> []
		,'doublesize'			=> 0
		,'idleBrightness'		=> 1
		,'irmap'				=> Slim::Hardware::IR::defaultMapFile()
		,'menuItem'				=> [qw( NOW_PLAYING
										BROWSE_MUSIC
										SEARCH
										SAVED_PLAYLISTS
										RADIO
										SETTINGS
										PLUGINS
							   )]
		,'mp3SilencePrelude' 	=> 0
		,'lameQuality'			=> 9
		,'offDisplaySize'		=> 0
		,'pitch'				=> 100
		,'playingDisplayMode'	=> 0
		,'power'				=> 1
		,'powerOffBrightness'	=> 1
		,'powerOnBrightness'	=> 4
		,'screensaver'			=> 'playlist'
		,'idlesaver'			=> 'playlist'
		,'offsaver'				=> 'SCREENSAVER.datetime'
		,'screensavertimeout'	=> 30
		,'scrollPause'			=> 3.6
		,'scrollPauseDouble'	=> 3.6
		,'scrollRate'			=> 0.15
		,'scrollRateDouble'		=> 0.1
		,'scrollPixels'         => 7
		,'scrollPixelsDouble'   => 7
		,'showbufferfullness'	=> 0
		,'silent'				=> 0
		,'syncPower'			=> 0
		,'syncVolume'			=> 0
		,'treble'				=> 50
		,'upgrade-5.4b1-script'		=> 1
		,'upgrade-5.4b2-script'		=> 1
		,'volume'				=> 50
		,'syncBufferThreshold'		=> 128
		,'bufferThreshold'		=> 255
	};

our %upgradeScripts = (

	# Allow the "upgrading" of old menu items to new ones.
	'5.4b1' => sub {

		my $client = shift;
		my $index  = 0;

		foreach my $menuItem (Slim::Utils::Prefs::clientGetArray($client,'menuItem')) {

			if ($menuItem eq 'ShoutcastBrowser') {
				Slim::Utils::Prefs::clientSet($client, 'menuItem', 'RADIO', $index);
				last;
			}

			$index++;
		}
	},

	'5.4b2' => sub {
		my $client = shift;

		my $addedBrowse = 0;
		my @newitems = ();

		foreach my $menuItem (Slim::Utils::Prefs::clientGetArray($client,'menuItem')) {

			if ($menuItem =~ 'BROWSE_') {

				if (!$addedBrowse) {
					push @newitems, 'BROWSE_MUSIC';
					$addedBrowse = 1;
				}

			} else {

				push @newitems, $menuItem;
			}
		}

		Slim::Utils::Prefs::clientSet($client, 'menuItem', \@newitems);
	},
);

sub new {
	my $class    = shift;
	my $id       = shift;
	my $paddr    = shift;
	my $revision = shift;

	my $client = $class->SUPER::new($id, $paddr);

	# initialize model-specific features:
	$client->revision($revision);

	return $client;
}

sub init {
	my $client = shift;

	# make sure any preferences this client may not have set are set to the default
	# This should be a method on client!
	Slim::Utils::Prefs::initClientPrefs($client, $defaultPrefs);

	$client->SUPER::init();
	
	for my $version (sort keys %upgradeScripts) {
		if (Slim::Utils::Prefs::clientGet($client, "upgrade-$version-script")) {
			&{$upgradeScripts{$version}}($client);
			Slim::Utils::Prefs::clientSet($client, "upgrade-$version-script", 0);
		}
	}

	Slim::Buttons::Home::updateMenu($client);

	# fire it up!
	$client->power(Slim::Utils::Prefs::clientGet($client,'power'));
	$client->startup();

	# start the screen saver
	Slim::Buttons::ScreenSaver::screenSaver($client);
	$client->brightness(Slim::Utils::Prefs::clientGet($client,$client->power() ? 'powerOnBrightness' : 'powerOffBrightness'));
}

# usage							float		buffer fullness as a percentage
sub usage {
	my $client = shift;
	return $client->bufferSize() ? $client->bufferFullness() / $client->bufferSize() : 0;
}

sub update {
	my $client = shift;
	my $lines = shift;
	my $nodoublesize = shift;

	unless ($client->param('noUpdate')) {

		$client->killAnimation();

		if (!defined($lines)) {
			Slim::Hardware::VFD::vfdUpdate($client, [Slim::Display::Display::curLines($client)]);
		} else {
			Slim::Hardware::VFD::vfdUpdate($client, $lines, $nodoublesize);
		}
	}
}	

sub isPlayer {
	return 1;
}

sub symbols {
	my $client = shift;
	my $line = shift;
	return $line;
}
	
# parse the stringified display commands into a hash.  try to extract them if
# they come as a reference to an array, a scalar, a reference to a scalar or
# even a pre-processed hash.
sub parseLines {
	my $client = shift;
	my $lines = shift;
	my %parts;
	my $line1 = '';
	my $line2 = '';
	my $line3;
	my $line4;
	my $overlay1 = '';
	my $overlay2 = '';
	my $center1 = '';
	my $center2 = '';
	my $bits = '';
	
	if (ref($lines) eq 'HASH') { 
		return $lines;
	} elsif (ref($lines) eq 'SCALAR') {
		$line1 = $$lines;
	} else {
		if (ref($lines) eq 'ARRAY') {
			$line1= $lines->[0];
			$line2= $lines->[1];
			$line3= $lines->[2];
			$line4= $lines->[3];
		} else {
			$line1 = $lines;
			$line2 = shift;
			$line3 = shift;
			$line4 = shift;
		}
		
		return $line1 if (ref($line1) eq 'HASH');
		
		if (!defined($line1)) { $line1 = ''; }
		if (!defined($line2)) { $line2 = ''; }

		$line1 .= "\x1eright\x1e" . $line3 if (defined($line3));

		$line2 .= "\x1eright\x1e" . $line4 if (defined($line4));

		if (length($line2)) { 
			$line1 .= "\x1elinebreak\x1e" . $line2;
		}
	}

	while ($line1 =~ s/\x1eframebuf\x1e(.*)\x1e\/framebuf\x1e//s) {
		$bits |= $1;
	}

	$line1 = $client->symbols($line1);
	($line1, $line2) = split("\x1elinebreak\x1e", $line1);

	if (!defined($line2)) { $line2 = '';}
	
	($line1, $overlay1) = split("\x1eright\x1e", $line1) if $line1;
	($line2, $overlay2) = split("\x1eright\x1e", $line2) if $line2;

	($line1, $center1) = split("\x1ecenter\x1e", $line1) if $line1;
	($line2, $center2) = split("\x1ecenter\x1e", $line2) if $line2;

	$line1 = '' if (!defined($line1));

	$parts{bits} = $bits;
	$parts{line1} = $line1;
	$parts{line2} = $line2;
	$parts{overlay1} = $overlay1;
	$parts{overlay2} = $overlay2;
	$parts{center1} = $center1;
	$parts{center2} = $center2;

	return \%parts;
}

sub power {
	my $client = shift;
	my $on = shift;
	
	my $currOn = Slim::Utils::Prefs::clientGet($client,'power') || 0;
	
	return $currOn unless defined $on;

	if (!defined(Slim::Buttons::Common::mode($client)) || ($currOn != $on)) {

		Slim::Utils::Prefs::clientSet($client, 'power', $on);

		unless ($on) {
			Slim::Buttons::Common::setMode($client, 'off');
			return;
		}

		Slim::Buttons::Common::setMode($client, 'home');
		
		my $welcome  = ($client->linesPerScreen() == 1) ? '' : Slim::Display::Display::center($client->string('WELCOME_TO_' . $client->model));
		my $welcome2 = ($client->linesPerScreen() == 1) ? '' : Slim::Display::Display::center($client->string('FREE_YOUR_MUSIC'));

		$client->showBriefly($welcome, $welcome2);
		
		# restore the saved brightness, unless its completely dark...
		my $powerOnBrightness = Slim::Utils::Prefs::clientGet($client, "powerOnBrightness");

		if ($powerOnBrightness < 1) { 
			$powerOnBrightness = 1;
		}

		Slim::Utils::Prefs::clientSet($client, "powerOnBrightness", $powerOnBrightness);

		# check if there is a sync group to restore
		Slim::Player::Sync::restoreSync($client);
	}
}

sub maxVolume { return 100; }
sub minVolume {	return 0; }

sub maxTreble {	return 100; }
sub minTreble {	return 0; }

sub maxBass {	return 100; }
sub minBass {	return 0; }

sub fonts {
	my $client = shift;
	my $size = shift;

	unless (defined $size) {
		$size = $client->textSize();
	}

	return $fonttable[$size];
}


# fade the volume up or down
# $fade = number of seconds to fade 100% (positive to fade up, negative to fade down) 
# $callback is function reference to be called when the fade is complete
our %fvolume;  # keep temporary fade volume for each client

sub fade_volume {
	my($client, $fade, $callback, $callbackargs) = @_;

	$::d_ui && msg("entering fade_volume:  fade: $fade to $fvolume{$client}\n");
	
	my $faderate = 20;  # how often do we send updated fade volume commands per second
	
	Slim::Utils::Timers::killTimers($client, \&fade_volume);
	
	my $vol = Slim::Utils::Prefs::clientGet($client, "volume");
	my $mute = Slim::Utils::Prefs::clientGet($client, "mute");
	if ($vol < 0 && $fade < 0) {
		# the volume is muted, don't fade.
		$callback && (&$callback(@$callbackargs));
		return;
	}
	
	if ($mute || (!$mute && $vol < 0)) {
		# Set Target (Negative indicates mute, but still saves old value)
		Slim::Utils::Prefs::clientSet($client, "volume", $vol * -1);
	}

	# on the first pass, set temporary fade volume
	if(!$fvolume{$client} && $fade > 0) {
		# fading up, start volume at 0
		$fvolume{$client} = 0;
	} elsif(!$fvolume{$client}) {
		# fading down, start volume at current volume
		$fvolume{$client} = $vol;
	}

	$fvolume{$client} += $client->maxVolume() * (1/$faderate) / $fade; # fade volume

	if ($fvolume{$client} < 0) { $fvolume{$client} = 0; };
	if ($fvolume{$client} > $vol) { $fvolume{$client} = $vol; };

	$client->volume($fvolume{$client},1); # set volume

	if ($fvolume{$client} == 0 || $fvolume{$client} == $vol) {	
		# done fading
		$::d_ui && msg("fade_volume done.  fade: $fade to $fvolume{$client} (vol: $vol)\n");
		$fvolume{$client} = 0; # reset temporary fade volume 
		$callback && (&$callback(@$callbackargs));
	} else {
		$::d_ui && msg("fade_volume - setting volume to $fvolume{$client} (originally $vol)\n");
		Slim::Utils::Timers::setTimer($client, Time::HiRes::time()+ (1/$faderate), \&fade_volume, ($fade, $callback, $callbackargs));
	}
}

# mute or un-mute volume as necessary
# A negative volume indicates that the player is muted and should be restored 
# to the absolute value when un-muted.
sub mute {
	my $client = shift;
	
	if (!$client->isPlayer()) {
		return 1;
	}

	my $vol = Slim::Utils::Prefs::clientGet($client, "volume");
	my $mute = Slim::Utils::Prefs::clientGet($client, "mute");
	
	if (($vol < 0) && ($mute)) {
		# mute volume
		# todo: there is actually a hardware mute feature
		# in both decoders. Need to add Decoder::mute
		$client->volume(0);;
	} else {
		# un-mute volume
		$vol *= -1;
		$client->volume($vol);
	}

	Slim::Utils::Prefs::clientSet($client, "volume", $vol);
	Slim::Display::Display::volumeDisplay($client);
}

sub brightness {
	my ($client,$delta, $noupdate) = @_;

	if (defined($delta) ) {
		if ($delta =~ /[\+\-]\d+/) {
			$client->currBrightness( ($client->currBrightness() + $delta) );
		} else {
			$client->currBrightness( $delta );
		}

		$client->currBrightness(0) if ($client->currBrightness() < 0);
		$client->currBrightness($client->maxBrightness()) if ($client->currBrightness() > $client->maxBrightness());
	
		if (!$noupdate) {
			my $temp1 = $client->prevline1();
			my $temp2 = $client->prevline2();
			$client->update([$temp1, $temp2], 1);
		}
	}
	
	my $brightness = $client->currBrightness();

	if (!defined($brightness)) { $brightness = $client->maxBrightness(); }	

	return $brightness;
}

sub maxBrightness {
	return $Slim::Hardware::VFD::MAXBRIGHTNESS;
}

sub textSize {
	my $client = shift;
	my $newsize = shift;
	
	my $prefname = ($client->power()) ? "doublesize" : "offDisplaySize";
	
	if (defined($newsize)) {
		return	Slim::Utils::Prefs::clientSet($client, $prefname, $newsize);
	} else {
		return	Slim::Utils::Prefs::clientGet($client, $prefname);
	}
}

# $client->textSize = 1 for LARGE text, 0 for small.
sub linesPerScreen {
	my $client = shift;
	return $client->textSize() ? 1 : 2;	
}

sub maxTextSize {
	return 1;
}

sub hasDigitalOut {
	return 0;
}
	
sub displayWidth {
	return 40;
}

sub currentSongLines {
	my $client = shift;
	my $parts;
	
	my $playlistlen = Slim::Player::Playlist::count($client);

	if ($playlistlen < 1) {

		$parts->{line1} = $client->string('NOW_PLAYING');
		$parts->{line2} = $client->string('NOTHING');

	} else {

		if (Slim::Player::Source::playmode($client) eq "pause") {

			$parts->{line1} = sprintf(
				$client->string('PAUSED')." (%d %s %d) ",
				Slim::Player::Source::playingSongIndex($client) + 1, $client->string('OUT_OF'), $playlistlen
			);

		# for taking photos of the display, comment out the line above, and use this one instead.
		# this will cause the display to show the "Now playing" screen to show when paused.
		# line1 = "Now playing" . sprintf " (%d %s %d) ", Slim::Player::Source::playingSongIndex($client) + 1, string('OUT_OF'), $playlistlen;

		} elsif (Slim::Player::Source::playmode($client) eq "stop") {

			$parts->{line1} = sprintf(
				$client->string('STOPPED')." (%d %s %d) ",
				Slim::Player::Source::playingSongIndex($client) + 1, $client->string('OUT_OF'), $playlistlen
			);

		} else {

			if (Slim::Player::Source::rate($client) != 1) {
				$parts->{line1} = $client->string('NOW_SCANNING') . ' ' . Slim::Player::Source::rate($client) . 'x';
			} elsif (Slim::Player::Playlist::shuffle($client)) {
				$parts->{line1} = $client->string('PLAYING_RANDOMLY');
			} else {
				$parts->{line1} = $client->string('PLAYING');
			}
			
			if ($client->volume() < 0) {
				$parts->{line1} .= " ". $client->string('LCMUTED');
			}

			$parts->{line1} = $parts->{line1} . sprintf(
				" (%d %s %d) ",
				Slim::Player::Source::playingSongIndex($client) + 1, $client->string('OUT_OF'), $playlistlen
			);
		} 

		$parts->{line2} = Slim::Music::Info::standardTitle($client, Slim::Player::Playlist::song($client));
		$parts->{overlay2} = $client->symbols(Slim::Display::Display::symbol('notesymbol'));

		# add in the progress bar and time...
		$client->nowPlayingModeLines($parts);
	}
	
	return $parts;
}

sub nowPlayingModes {
	my $client = shift;
	my $count = Slim::Utils::Prefs::clientGet($client,'showbufferfullness') ? 7 : 6;
	return $count;
}

sub nowPlayingModeLines {
	my ($client, $parts) = @_;
	my $overlay;
	my $fractioncomplete   = 0;
	my $playingDisplayMode = Slim::Utils::Prefs::clientGet($client, "playingDisplayMode");

	$client->param(
		'animateTop',
		(Slim::Player::Source::playmode($client) ne "stop") ? $playingDisplayMode : 0
	);

	unless (defined $playingDisplayMode) {
		$playingDisplayMode = 1;
	};

	# check if we don't know how long the track is...
	if (!Slim::Player::Source::playingSongDuration($client) && ($playingDisplayMode != 6)) {
		# no progress bar, remaining time is meaningless
		$playingDisplayMode = ($playingDisplayMode % 3) ? 1 : 0;

	} else {
		$fractioncomplete = Slim::Player::Source::progress($client);
	}

	my $songtime = " " . Slim::Player::Source::textSongTime($client, $playingDisplayMode);

	if ( $playingDisplayMode == 6) {
		if (!Slim::Utils::Prefs::clientGet($client,'showbufferfullness')) {
			$playingDisplayMode = 1; #sanity check.  revert to showing nothign is showbufferfullnes has been turned off.
		} else {
			# show both the usage bar and numerical usage
			$fractioncomplete = $client->usage();
			my $usageLine = ' ' . int($fractioncomplete * 100 + 0.5)."%";
			my $usageLineLength = $client->measureText($usageLine,1);
			
			my $leftLength = $client->measureText($parts->{line1}, 1);
			my $barlen = $client->displayWidth()  - $leftLength - $usageLineLength;
			my $bar    = $client->symbols($client->progressBar($barlen, $fractioncomplete));
	
			$overlay = $bar . $usageLine;
		}
	}
	
	if ($playingDisplayMode == 1 || $playingDisplayMode == 2) {
		$overlay = $songtime;

	} elsif ($playingDisplayMode == 3) {

		# just show the bar
		my $leftLength = $client->measureText($parts->{line1}, 1);
		my $barlen = $client->displayWidth() - $leftLength;
		my $bar    = $client->symbols($client->progressBar($barlen, $fractioncomplete));

		$overlay = $bar;

	} elsif ($playingDisplayMode == 4 || $playingDisplayMode == 5) {

		# show both the bar and the time
		my $leftLength = $client->measureText($parts->{line1}, 1);
		my $barlen = $client->displayWidth() - $leftLength - $client->measureText($songtime, 1);

		my $bar    = $client->symbols($client->progressBar($barlen, $fractioncomplete));

		$overlay = $bar . $songtime;
	}
	$parts->{overlay1} = $overlay;
	return $parts;
}

sub measureText {
	my $client = shift;
	my $text = shift;
	my $line = shift;
	
	return Slim::Display::Display::lineLength($text);
}

sub killAnimation {
	Slim::Display::VFD::Animation::killAnimation(@_);
}

sub endAnimation {
	Slim::Display::VFD::Animation::endAnimation(@_);
}

sub showBriefly {
	Slim::Display::VFD::Animation::showBriefly(@_);
}

sub pushLeft {
	Slim::Display::VFD::Animation::pushLeft(@_);
}

sub pushRight {
	Slim::Display::VFD::Animation::pushRight(@_);
}

sub doEasterEgg {
	Slim::Display::VFD::Animation::doEasterEgg(@_);
}

sub bumpLeft {
	Slim::Display::VFD::Animation::bumpLeft(@_);
}

sub bumpRight {
	Slim::Display::VFD::Animation::bumpRight(@_);
}

sub bumpUp {
	Slim::Display::VFD::Animation::bumpUp(@_);
}

sub bumpDown {
	Slim::Display::VFD::Animation::bumpDown(@_);
}

sub scrollBottom {
	Slim::Display::VFD::Animation::scrollBottom(@_);
}
	
sub renderOverlay {
	my $client = shift;
	my $line1 = shift || '';
	my $line2 = shift || '';
	my $overlay1 = shift;
	my $overlay2 = shift;
	
	return $line1 if (ref($line1) eq 'HASH');
	return $line1 if $line1 =~ /\x1e(framebuf|linebreak|right)\x1e/s;

	if (defined($overlay1)) { 
		$line1 .= "\x1eright\x1e" . $overlay1;
	}
	
	if (defined($overlay2) || defined($line2)) {
		$line1 .= "\x1elinebreak\x1e";
	}
	
	if (defined($line2)) {
		$line1 .= $line2;
	}
	
	if (defined($overlay2)) {
		$line1 .= "\x1eright\x1e" . $overlay2;
	}

	return $line1;
}

# Draws a slider bar, bidirectional or single direction is possible.
# $value should be pre-processed to be from 0-100
# $midpoint specifies the position of the divider from 0-100 (use 0 for progressBar)
# returns a +/- balance/bass/treble bar text AND sets up custom characters if necessary
# range 0 to 100, 50 is middle.
sub sliderBar {
	my ($client,$width,$value,$midpoint,$fullstep) = @_;
	$midpoint = 0 unless defined $midpoint;
	if ($width == 0) {
		return "";
	}
	
	my $charwidth = 5;

	if ($value < 0) {
		$value = 0;
	}
	
	if ($value > 100) {
		$value = 100;
	}
	
	my $chart = "";
	
	my $totaldots = $charwidth + ($width - 2) * $charwidth + $charwidth;

	# felix mueller discovered some rounding errors that were causing the
	# calculations to be off.  Doing it 1000 times up seems to be better.  
	# go figure.
	my $dots = int( ( ( $value * 10 ) * $totaldots) / 1000);
	my $divider = ($midpoint/100) * ($width-2);

	my $val = $value/100 * $width;
	$width = $width - 1 if $midpoint;
	
	if ($dots < 0) { $dots = 0 };
	
	if ($dots < $charwidth) {
		$chart = $midpoint ? Slim::Display::Display::symbol('leftprogress4') : Slim::Display::Display::symbol('leftprogress'.$dots);
	} else {
		$chart = $midpoint ? Slim::Display::Display::symbol('leftprogress0') : Slim::Display::Display::symbol('leftprogress4');
	}
	
	$dots -= $charwidth;
			
	if ($midpoint) {
		for (my $i = 1; $i < $divider; $i++) {
			if ($dots <= 0) {
				$chart .= Slim::Display::Display::symbol('solidblock');
			} else {
				$chart .= Slim::Display::Display::symbol('middleprogress0');
			}
			$dots -= $charwidth;
		}
		if ($value < $midpoint) {
			$chart .= Slim::Display::Display::symbol('solidblock');
			$dots -= $charwidth;
		} else {
			$chart .= Slim::Display::Display::symbol('leftmark');
			$dots -= $charwidth;
		}
	}
	for (my $i = $divider + 1; $i < ($width - 1); $i++) {
		if ($midpoint && $i == $divider + 1) {
			if ($value > $midpoint) {
				$chart .= Slim::Display::Display::symbol('solidblock');
			} else {
				$chart .= Slim::Display::Display::symbol('rightmark');
			}
			$dots -= $charwidth;
		}
		if ($dots <= 0) {
			$chart .= Slim::Display::Display::symbol('middleprogress0');
		} elsif ($dots < $charwidth && !$fullstep) {
			$chart .= Slim::Display::Display::symbol('middleprogress'.$dots);
		} else {
			$chart .= Slim::Display::Display::symbol('solidblock');
		}
		$dots -= $charwidth;
	}
		
	if ($dots <= 0) {
		$chart .= Slim::Display::Display::symbol('rightprogress0');
	} elsif ($dots < $charwidth && !$fullstep) {
		$chart .= Slim::Display::Display::symbol('rightprogress'.$dots);
	} else {
		$chart .= Slim::Display::Display::symbol('rightprogress4');
	}
	
	return $chart;
}

# returns progress bar text
sub progressBar {
	return sliderBar(shift,shift,(shift)*100,0);
}

sub balanceBar {
	return sliderBar(shift,shift,shift,50);
}

sub textSongTime {
	my $client = shift;
	my $remaining = shift;

	my $delta = 0;
	my $sign  = '';

	if (Slim::Player::Source::playmode($client) eq "stop") {
		$delta = 0;
	} else {	
		$delta = Slim::Player::Source::songTime($client);
	}
	
	# 2 and 5 display remaining time, not elapsed
	if ($remaining) {
		my $duration = Slim::Player::Source::playingSongDuration($client) || 0;
		if ($duration) {
			$delta = $duration - $delta;	
			$sign = '-';
		}
	}
	
	my $hrs = int($delta / (60 * 60));
	my $min = int(($delta - $hrs * 60 * 60) / 60);
	my $sec = $delta - ($hrs * 60 * 60 + $min * 60);
	
	my $time;
	if ($hrs) {
		$time = sprintf("%s%d:%02d:%02d", $sign, $hrs, $min, $sec);
	} else {
		$time = sprintf("%s%02d:%02d", $sign, $min, $sec);
	}
	return $time;
}

1;

__END__
