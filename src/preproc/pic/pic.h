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

#include "lib.h"

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <assert.h>
#include <errno.h>
#include <math.h>
#include <stdlib.h>

#ifdef NEED_DECLARATION_RAND
#undef rand
extern "C" {
  int rand();
}
#endif /* NEED_DECLARATION_RAND */

#ifdef NEED_DECLARATION_SRAND
#undef srand
extern "C" {
#ifdef RET_TYPE_SRAND_IS_VOID
  void srand(unsigned int);
#else
  int srand(unsigned int);
#endif
}
#endif /* NEED_DECLARATION_SRAND */

#ifndef HAVE_FMOD
extern "C" {
  double fmod(double, double);
}
#endif

#include "cset.h"
#include "stringclass.h"
#include "lf.h"
#include "errarg.h"
#include "error.h"
#include "position.h"
#include "text.h"
#include "output.h"

#ifndef M_SQRT2
#define M_SQRT2	1.41421356237309504880
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

class input {
  input *next;
public:
  input();
  virtual ~input();
  virtual int get() = 0;
  virtual int peek() = 0;
  virtual int get_location(const char **, int *);
  friend class input_stack;
  friend class copy_rest_thru_input;
};

class file_input : public input {
  FILE *fp;
  const char *filename;
  int lineno;
  string line;
  const char *ptr;
  int read_line();
public:
  file_input(FILE *, const char *);
  ~file_input();
  int get();
  int peek();
  int get_location(const char **, int *);
};

void lex_init(input *);
int get_location(char **, int *);

void do_copy(const char *file);
void parse_init();
void parse_cleanup();

void lex_error(const char *message,
	       const errarg &arg1 = empty_errarg,
	       const errarg &arg2 = empty_errarg,
	       const errarg &arg3 = empty_errarg);

void lex_warning(const char *message,
		 const errarg &arg1 = empty_errarg,
		 const errarg &arg2 = empty_errarg,
		 const errarg &arg3 = empty_errarg);

void lex_cleanup();

extern bool want_flyback;
extern bool want_alternate_flyback;
extern int command_char;
// zero_length_line_flag is non-zero if zero-length lines are drawn 
// as dots by the output device
extern int zero_length_line_flag;
extern int driver_extension_flag;
extern int compatible_flag;
extern int safer_flag;
extern char *graphname;

// Local Variables:
// fill-column: 72
// mode: C++
// End:
// vim: set cindent noexpandtab shiftwidth=2 textwidth=72:
