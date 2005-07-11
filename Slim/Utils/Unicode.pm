package Slim::Utils::Unicode;

# $Id$

use strict;

# Useful parts lifted from Simon's defunct Unicode::Decompose
#
# This module currently implements a recompose() function to handle Unicode
# characters that somehow become decomposed. Sometimes we'll see a URI
# encoding such as: o%CC%88 - which is an o with diaeresis. The correct
# (composed) version of this should be %C3%B6
#
# This code isn't in use anywhere - but James Craig was seeing it in his
# iTunesControl Plugin. I've added it to the tree with the intent of moving
# all of the utf8/latin1/encoding functions from Slim::Utils::Misc here at a
# later date.

if ($] > 5.007) {
	require Encode;
}

my $recomposeTable = {
	"o\x{30c}" => "\x{1d2}",
	"e\x{302}" => "\x{ea}",
	"i\x{306}" => "\x{12d}",
	"h\x{302}" => "\x{125}",
	"u\x{300}" => "\x{f9}",
	"O\x{302}" => "\x{d4}",
	"s\x{327}" => "\x{15f}",
	"i\x{308}" => "\x{ef}",
	"I\x{30f}" => "\x{208}",
	"A\x{303}" => "\x{c3}",
	"U\x{308}\x{30c}" => "\x{1d9}",
	"U\x{301}" => "\x{da}",
	"c\x{30c}" => "\x{10d}",
	"u\x{308}\x{304}" => "\x{1d6}",
	"r\x{301}" => "\x{155}",
	"o\x{301}" => "\x{f3}",
	"y\x{301}" => "\x{fd}",
	"I\x{301}" => "\x{cd}",
	"A\x{30f}" => "\x{200}",
	"i\x{303}" => "\x{129}",
	"Y\x{301}" => "\x{dd}",
	"A\x{302}" => "\x{c2}",
	"e\x{311}" => "\x{207}",
	"a\x{302}" => "\x{e2}",
	"a\x{328}" => "\x{105}",
	"U\x{304}" => "\x{16a}",
	"L\x{301}" => "\x{139}",
	"I\x{328}" => "\x{12e}",
	"u\x{30b}" => "\x{171}",
	"a\x{308}" => "\x{e4}",
	"u\x{306}" => "\x{16d}",
	"u\x{303}" => "\x{169}",
	"U\x{308}\x{301}" => "\x{1d7}",
	"I\x{303}" => "\x{128}",
	"G\x{306}" => "\x{11e}",
	"a\x{30a}" => "\x{e5}",
	"i\x{301}" => "\x{ed}",
	"t\x{30c}" => "\x{165}",
	"e\x{304}" => "\x{113}",
	"E\x{328}" => "\x{118}",
	"S\x{327}" => "\x{15e}",
	"u\x{308}\x{30c}" => "\x{1da}",
	"\x{226}\x{304}" => "\x{1e0}",
	"R\x{301}" => "\x{154}",
	"c\x{301}" => "\x{107}",
	"E\x{30f}" => "\x{204}",
	"N\x{300}" => "\x{1f8}",
	"U\x{302}" => "\x{db}",
	"o\x{302}" => "\x{f4}",
	"s\x{30c}" => "\x{161}",
	"U\x{30b}" => "\x{170}",
	"E\x{304}" => "\x{112}",
	"U\x{328}" => "\x{172}",
	"n\x{327}" => "\x{146}",
	"G\x{30c}" => "\x{1e6}",
	"a\x{311}" => "\x{203}",
	"\x{f8}\x{301}" => "\x{1ff}",
	"A\x{30a}" => "\x{c5}",
	"s\x{301}" => "\x{15b}",
	"Y\x{308}" => "\x{178}",
	"E\x{30c}" => "\x{11a}",
	"\x{292}\x{30c}" => "\x{1ef}",
	"A\x{308}" => "\x{c4}",
	"U\x{308}\x{304}" => "\x{1d5}",
	"T\x{30c}" => "\x{164}",
	"O\x{304}" => "\x{14c}",
	"A\x{328}" => "\x{104}",
	"a\x{30c}" => "\x{1ce}",
	"A\x{300}" => "\x{c0}",
	"o\x{311}" => "\x{20f}",
	"I\x{300}" => "\x{cc}",
	"U\x{31b}" => "\x{1af}",
	"\x{c6}\x{301}" => "\x{1fc}",
	"u\x{308}\x{300}" => "\x{1dc}",
	"k\x{327}" => "\x{137}",
	"Z\x{307}" => "\x{17b}",
	"E\x{302}" => "\x{ca}",
	"E\x{308}" => "\x{cb}",
	"n\x{303}" => "\x{f1}",
	"R\x{30c}" => "\x{158}",
	"D\x{30c}" => "\x{10e}",
	"c\x{302}" => "\x{109}",
	"L\x{30c}" => "\x{13d}",
	"N\x{301}" => "\x{143}",
	"N\x{30c}" => "\x{147}",
	"A\x{304}" => "\x{100}",
	"u\x{302}" => "\x{fb}",
	"I\x{308}" => "\x{cf}",
	"S\x{302}" => "\x{15c}",
	"O\x{30c}" => "\x{1d1}",
	"j\x{302}" => "\x{135}",
	"S\x{301}" => "\x{15a}",
	"\x{1b7}\x{30c}" => "\x{1ee}",
	"K\x{327}" => "\x{136}",
	"z\x{301}" => "\x{17a}",
	"O\x{300}" => "\x{d2}",
	"O\x{31b}" => "\x{1a0}",
	"O\x{328}" => "\x{1ea}",
	"o\x{31b}" => "\x{1a1}",
	"E\x{311}" => "\x{206}",
	"a\x{308}\x{304}" => "\x{1df}",
	"n\x{301}" => "\x{144}",
	"U\x{300}" => "\x{d9}",
	"g\x{301}" => "\x{1f5}",
	"i\x{304}" => "\x{12b}",
	"i\x{328}" => "\x{12f}",
	"k\x{30c}" => "\x{1e9}",
	"y\x{308}" => "\x{ff}",
	"E\x{306}" => "\x{114}",
	"g\x{307}" => "\x{121}",
	"z\x{30c}" => "\x{17e}",
	"a\x{300}" => "\x{e0}",
	"u\x{304}" => "\x{16b}",
	"e\x{308}" => "\x{eb}",
	"u\x{30c}" => "\x{1d4}",
	"e\x{301}" => "\x{e9}",
	"i\x{300}" => "\x{ec}",
	"u\x{31b}" => "\x{1b0}",
	"r\x{30c}" => "\x{159}",
	"g\x{302}" => "\x{11d}",
	"W\x{302}" => "\x{174}",
	"O\x{301}" => "\x{d3}",
	"e\x{328}" => "\x{119}",
	"A\x{306}" => "\x{102}",
	"a\x{306}" => "\x{103}",
	"S\x{30c}" => "\x{160}",
	"I\x{302}" => "\x{ce}",
	"R\x{327}" => "\x{156}",
	"w\x{302}" => "\x{175}",
	"U\x{308}" => "\x{dc}",
	"C\x{307}" => "\x{10a}",
	"I\x{306}" => "\x{12c}",
	"O\x{30f}" => "\x{20c}",
	"N\x{327}" => "\x{145}",
	"C\x{302}" => "\x{108}",
	"u\x{328}" => "\x{173}",
	"o\x{303}" => "\x{f5}",
	"r\x{327}" => "\x{157}",
	"U\x{30a}" => "\x{16e}",
	"i\x{302}" => "\x{ee}",
	"i\x{30c}" => "\x{1d0}",
	"E\x{307}" => "\x{116}",
	"O\x{328}\x{304}" => "\x{1ec}",
	"c\x{307}" => "\x{10b}",
	"Z\x{301}" => "\x{179}",
	"\x{e6}\x{304}" => "\x{1e3}",
	"E\x{301}" => "\x{c9}",
	"Y\x{302}" => "\x{176}",
	"o\x{308}" => "\x{f6}",
	"g\x{327}" => "\x{123}",
	"l\x{301}" => "\x{13a}",
	"u\x{308}" => "\x{fc}",
	"l\x{30c}" => "\x{13e}",
	"g\x{306}" => "\x{11f}",
	"A\x{301}" => "\x{c1}",
	"\x{e6}\x{301}" => "\x{1fd}",
	"C\x{327}" => "\x{c7}",
	"C\x{30c}" => "\x{10c}",
	"a\x{303}" => "\x{e3}",
	"a\x{30a}\x{301}" => "\x{1fb}",
	"o\x{30b}" => "\x{151}",
	"O\x{308}" => "\x{d6}",
	"z\x{307}" => "\x{17c}",
	"A\x{30a}\x{301}" => "\x{1fa}",
	"d\x{30c}" => "\x{10f}",
	"s\x{302}" => "\x{15d}",
	"R\x{30f}" => "\x{210}",
	"I\x{30c}" => "\x{1cf}",
	"U\x{303}" => "\x{168}",
	"i\x{311}" => "\x{20b}",
	"O\x{30b}" => "\x{150}",
	"u\x{308}\x{301}" => "\x{1d8}",
	"G\x{327}" => "\x{122}",
	"U\x{306}" => "\x{16c}",
	"e\x{306}" => "\x{115}",
	"u\x{301}" => "\x{fa}",
	"\x{227}\x{304}" => "\x{1e1}",
	"a\x{304}" => "\x{101}",
	"T\x{327}" => "\x{162}",
	"U\x{308}\x{300}" => "\x{1db}",
	"n\x{300}" => "\x{1f9}",
	"I\x{311}" => "\x{20a}",
	"A\x{308}\x{304}" => "\x{1de}",
	"I\x{307}" => "\x{130}",
	"\x{d8}\x{301}" => "\x{1fe}",
	"A\x{30c}" => "\x{1cd}",
	"I\x{304}" => "\x{12a}",
	"c\x{327}" => "\x{e7}",
	"o\x{328}\x{304}" => "\x{1ed}",
	"t\x{327}" => "\x{163}",
	"G\x{307}" => "\x{120}",
	"G\x{301}" => "\x{1f4}",
	"o\x{328}" => "\x{1eb}",
	"N\x{303}" => "\x{d1}",
	"O\x{311}" => "\x{20e}",
	"e\x{307}" => "\x{117}",
	"g\x{30c}" => "\x{1e7}",
	"Z\x{30c}" => "\x{17d}",
	"o\x{304}" => "\x{14d}",
	"L\x{327}" => "\x{13b}",
	"U\x{30c}" => "\x{1d3}",
	"o\x{306}" => "\x{14f}",
	"C\x{301}" => "\x{106}",
	"H\x{302}" => "\x{124}",
	"e\x{30f}" => "\x{205}",
	"J\x{302}" => "\x{134}",
	"\x{c6}\x{304}" => "\x{1e2}",
	"e\x{30c}" => "\x{11b}",
	"y\x{302}" => "\x{177}",
	"O\x{303}" => "\x{d5}",
	"o\x{30f}" => "\x{20d}",
	"K\x{30c}" => "\x{1e8}",
	"E\x{300}" => "\x{c8}",
	"a\x{301}" => "\x{e1}",
	"G\x{302}" => "\x{11c}",
	"o\x{300}" => "\x{f2}",
	"a\x{30f}" => "\x{201}",
	"l\x{327}" => "\x{13c}",
	"O\x{306}" => "\x{14e}",
	"A\x{311}" => "\x{202}",
	"j\x{30c}" => "\x{1f0}",
	"n\x{30c}" => "\x{148}",
	"e\x{300}" => "\x{e8}",
	"u\x{30a}" => "\x{16f}",
	"i\x{30f}" => "\x{209}"
};

my $decomposeTable = {};

while (my ($key, $value) = each %{$recomposeTable}) {
	$decomposeTable->{$value} = $key;
}

# Create a compiled regex.
my $recomposeRE = join "|", reverse sort keys %{$recomposeTable};
   $recomposeRE = qr/($recomposeRE)/o;

my $decomposeRE = join "|", reverse sort keys %{$decomposeTable};
   $decomposeRE = qr/($decomposeRE)/o;

sub recomposeUnicode {
	my $string = shift;

	if ($] <= 5.007) {
		return $string;
	}

	# Make sure we're on.
	$string = Encode::decode('utf8', $string);

	$string =~ s/$recomposeRE/$recomposeTable->{$1}/go;

	$string = Encode::encode('utf8', $string);

	return $string;
}

sub decomposeUnicode {
	my $string = shift;

	if ($] <= 5.007) {
		return $string;
	}

	# Make sure we're on.
	$string = Encode::decode('utf8', $string);

	$string =~ s/$decomposeRE/$decomposeTable->{$1}/go;

	$string = Encode::encode('utf8', $string);

	return $string;
}

1;

__END__
