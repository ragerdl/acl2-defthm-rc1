; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
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

; There doesn't seem to be any mechanism for just printing the contents of a
; string without any formatting using cw.  Using ~s mostly works, but it will
; insert its own line breaks.  Using ~f fixes that, but puts quotes around the
; string.  So, here we introduce a routine that just prints the contents of a
; string without any automatic line breaks and without the surrounding quotes.
; This can be combined usefully with our printer (see print.lisp).

(defun cw-unformatted (x)
  (declare (xargs :guard (stringp x))
           (ignore x))
  (er hard? 'cw-unformatted "Raw lisp definition not installed?"))

(defttag cw-unformatted)

; (depends-on "cw-unformatted-raw.lsp")
(include-raw "cw-unformatted-raw.lsp")

(defttag nil)


#||
;; Alternate implementation doesn't need a trust tag...

(defun cw-princ$ (str)
  ;; Same as princ$ to *standard-co*, but doesn't require state.
  (declare (xargs :guard t))
  (mbe :logic nil
       :exec
       (wormhole 'cw-raw-wormhole
                 '(lambda (whs) whs)
                 nil
                 `(let ((state (princ$ ',str *standard-co* state)))
                    (value :q))
                 :ld-prompt nil
                 :ld-pre-eval-print nil
                 :ld-post-eval-print nil
                 :ld-verbose nil)))


||#
