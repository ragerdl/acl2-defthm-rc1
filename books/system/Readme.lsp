(
 (:files
 "
.:
Makefile
Readme.lsp
hl-addr-combine.lisp
pseudo-good-worldp.lisp
too-many-ifs.lisp
top.lisp
verified-guards.lisp
verified-termination.lisp
worldp-check.acl2
worldp-check.lisp
"
 )
 (:TITLE "System Books")
 (:AUTHOR/S
  "Jared Davis for hl-addr-combine.lisp; Matt Kaufmann and J Moore for the rest")
 (:Keywords "Logical World")
 (:ABSTRACT

"These books are about system-level properties, for example checking invariants
on the ACL2 logical world and verifying termination and guards of some system
functions.  The scope may broaden in the future.

The book top.lisp includes books verifying termination and guards of system
functions.  Add an include-book to top.lisp for each new such book.

verified-guards.lisp verifies the guards of some ACL2 system functions

verified-termination.lisp admits some :program mode ACL2 system functions into
the logic by verifying their termination."  
)
 (:PERMISSION

"
This program is free software; you can redistribute it and/ormodify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc., 51
Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA."
))
