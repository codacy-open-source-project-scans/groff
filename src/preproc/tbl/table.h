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

#include <stdlib.h>
#include <ctype.h>
#include <errno.h>

#include "cset.h"
#include "cmap.h"
#include "stringclass.h"
#include "errarg.h"
#include "error.h"
#include "lf.h"

// PREFIX and PREFIX_CHAR must be the same.
#define PREFIX "3"
#define PREFIX_CHAR '3'

// LEADER and LEADER_CHAR must be the same.
#define LEADER "a"
#define LEADER_CHAR 'a'

struct size_expression {
  enum { DECREMENT = -1, ABSOLUTE, INCREMENT } relativity;
  int whole;
};

struct entry_modifier {
  size_expression type_size;
  size_expression vertical_spacing;
  string font;
  string macro;
  enum { CENTER, TOP, BOTTOM } vertical_alignment;
  char zero_width;
  char stagger;

  entry_modifier();
  ~entry_modifier();
};

enum format_type {
  FORMAT_LEFT,
  FORMAT_CENTER,
  FORMAT_RIGHT,
  FORMAT_NUMERIC,
  FORMAT_ALPHABETIC,
  FORMAT_SPAN,
  FORMAT_VSPAN,
  FORMAT_HRULE,
  FORMAT_DOUBLE_HRULE
};

struct entry_format : public entry_modifier {
  format_type type;

  entry_format(format_type);
  entry_format();
  void debug_print() const;
};

class table_entry;
struct horizontal_span;
struct stuff;
struct vertical_rule;

class table {
  int nrows;
  int ncolumns;
  int linesize;
  char delim[2];
  char decimal_point_char;
  vertical_rule *vrule_list;
  stuff *stuff_list;
  horizontal_span *span_list;
  table_entry *entry_list;
  table_entry **entry_list_tailp;
  table_entry ***entry;
  char **vrule;
  char *row_is_all_lines;
  string *minimum_width;
  int *column_separation;
  char *equal;
  int left_separation; // from a vertical rule or box border, in ens
  int right_separation; // from a vertical rule or box border, in ens
  int total_separation;
  int allocated_rows;
  void build_span_list();
  void compute_overall_width();
  void do_hspan(int r, int c);
  void do_vspan(int r, int c);
  void allocate(int r);
  void compute_widths();
  void divide_span(int, int);
  void sum_columns(int, int, int);
  void compute_total_separation();
  void compute_separation_factor();
  void compute_column_positions();
  void do_row(int);
  void init_output();
  void add_stuff(stuff *);
  void do_top();
  void do_bottom();
  void do_vertical_rules();
  void build_vrule_list();
  void add_vertical_rule(int, int, int, int);
  void define_bottom_macro();
  int vrule_spanned(int r, int c);
  int row_begins_section(int);
  int row_ends_section(int);
  void make_columns_equal();
  void compute_vrule_top_adjust(int, int, string &);
  void compute_vrule_bot_adjust(int, int, string &);
  void determine_row_type();
  int count_expand_columns();
public:
  unsigned flags;
  enum {
    CENTER         = 0x00000001,
    EXPAND         = 0x00000002,
    BOX            = 0x00000004,
    ALLBOX         = 0x00000008,
    DOUBLEBOX      = 0x00000010,
    NOKEEP         = 0x00000020,
    NOSPACES       = 0x00000040,
    NOWARN         = 0x00000080,
    // The next few properties help manage nroff mode output.
    HAS_TOP_VRULE  = 0x00000100,
    HAS_TOP_HRULE  = 0x00000200,
    HAS_DATA_HRULE = 0x00000400,
    GAP_EXPAND     = 0x00000800,
    EXPERIMENTAL   = 0x80000000 // undocumented
    };
  char *expand;
  table(int nc, unsigned flags, int linesize, char decimal_point_char);
  ~table();

  void add_text_line(int r, const string &, const char *, int);
  void add_single_hrule(int r);
  void add_double_hrule(int r);
  void add_entry(int r, int c, const string &, const entry_format *,
		 const char *, int lineno);
  void add_vrules(int r, const char *);
  void check();
  void print();
  void set_minimum_width(int c, const string &w);
  void set_column_separation(int c, int n);
  void set_equal_column(int c);
  void set_expand_column(int c);
  void set_delim(char c1, char c2);
  void print_single_hrule(int r);
  void print_double_hrule(int r);
  int get_nrows();
};

void set_troff_location(const char *, int);

extern int compatible_flag;

// Local Variables:
// fill-column: 72
// mode: C++
// End:
// vim: set cindent noexpandtab shiftwidth=2 textwidth=72:
