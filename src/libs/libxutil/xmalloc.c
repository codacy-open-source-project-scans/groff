/* Copyright (C) 2014-2020 Free Software Foundation, Inc.

This file is part of groff.

groff is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation, either version 2 of the License, or
(at your option) any later version.

groff is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

The GNU General Public License version 2 (GPL2) is available in the
internet at <http://www.gnu.org/licenses/gpl-2.0.txt>. */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <X11/Xlib.h>
#include <X11/Intrinsic.h>

char *xmalloc(int n);

char *xmalloc(int n)
{
	return XtMalloc(n);
}
