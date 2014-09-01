; ACL2 Quicklisp Interface
; Copyright (C) 2008-2014 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; License: (An MIT/X11-style license)
;
;   Permission is hereby granted, free of charge, to any person obtaining a
;   copy of this software and associated documentation files (the "Software"),
;   to deal in the Software without restriction, including without limitation
;   the rights to use, copy, modify, merge, publish, distribute, sublicense,
;   and/or sell copies of the Software, and to permit persons to whom the
;   Software is furnished to do so, subject to the following conditions:
;
;   The above copyright notice and this permission notice shall be included in
;   all copies or substantial portions of the Software.
;
;   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;   DEALINGS IN THE SOFTWARE.
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "ACL2")
(include-book "tools/include-raw" :dir :system)
; cert_param: (uses-quicklisp)

(make-event
 (let ((cbd (cbd)))
   `(defconst *quicklisp-dir* ',cbd)))

(make-event
 (let* ((dir *quicklisp-dir*))
   ;; Keep these in sync with install.lsp
   (progn$
    (setenv$ "XDG_CONFIG_HOME" (concatenate 'string dir "asdf-home/config"))
    (setenv$ "XDG_DATA_HOME"   (concatenate 'string dir "asdf-home/data"))
    (setenv$ "XDG_CACHE_HOME"  (concatenate 'string dir "asdf-home/cache"))
    (value '(value-triple :invisible))))
 :check-expansion t)

(defttag :quicklisp)

(value-triple (cw "~%~%~
***********************************************************************~%~
*****                                                             *****~%~
*****                  IF YOUR BUILD FAILS                        *****~%~
*****                                                             *****~%~
***** The include-raw form here can fail if you try to certify    *****~%~
***** this book without first getting quicklisp installed.  You   *****~%~
***** need to run 'make' first.                                   *****~%~
*****                                                             *****~%~
***** See books/centaur/README.html for detailed directions for   *****~%~
***** properly building the Centaur books.                        *****~%~
*****                                                             *****~%~
***********************************************************************~%~
~%"))

; (depends-on "inst/setup.lisp")
(include-raw "inst/setup.lisp"
             :do-not-compile t
             :host-readtable t)

; (depends-on "base-raw.lsp")
(local (include-raw "base-raw.lsp" :host-readtable t))
