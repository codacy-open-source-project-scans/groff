/* Copyright (C) 1989-2020 Free Software Foundation, Inc.
     Written by James Clark (jjc@jclark.com)

This file is part of groff.

groff is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or
(at your option) any later version.

groff is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <math.h>
#include <errno.h>

#ifdef HAVE_STRUCT_EXCEPTION
#ifdef TLOSS

int matherr(exc)
struct exception *exc;
{
  switch (exc->type) {
  case SING:
  case DOMAIN:
    errno = EDOM;
    break;
  case OVERFLOW:
  case UNDERFLOW:
  case TLOSS:
  case PLOSS:
    errno = ERANGE;
    break;
  }
  return 1;
}

#endif /* TLOSS */
#endif /* HAVE_STRUCT_EXCEPTION */

// Local Variables:
// fill-column: 72
// mode: C++
// End:
// vim: set cindent noexpandtab shiftwidth=2 textwidth=72:
