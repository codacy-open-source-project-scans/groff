#!/bin/sh
#
# Copyright (C) 2022-2024 Free Software Foundation, Inc.
#
# This file is part of groff.
#
# groff is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# groff is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

groff="${abs_top_builddir:-.}/test-groff"

fail=

wail() {
    echo ...FAILED >&2
    fail=yes
}

# Regression-test Savannah #59738.  The processing of arguments after
# the link text should not break end-of-sentence detection.

input='.Dd 2022-09-15
.Dt foo 1
.Os "groff test suite"
.Sh Name
.Nm foo
.Nd frobnicate a bar
.Sh Description
Click
.Lk http://example.com here .
Follow instructions.'

echo "checking output when hyperlinks disabled" >&2
output=$(echo "$input" | "$groff" -rU0 -Tascii -P-cbou -mdoc)
echo "$output"
echo "$output" | grep -Fq 'com>.  Follow' || wail # 2 spaces

echo "checking output when hyperlinks enabled" >&2
output=$(echo "$input" | "$groff" -rU1 -Tascii -P-cbou -mdoc)
echo "$output"
echo "$output" | grep -Fq 'here.  Follow' || wail # 2 spaces

# vim:set ai et sw=4 ts=4 tw=72:
