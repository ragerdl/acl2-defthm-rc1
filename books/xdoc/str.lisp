; XDOC Documentation System for ACL2
; Copyright (C) 2009-2014 Centaur Technology
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

; str.lisp
;
; This is basically similar to books such as std/strings/defs.lisp or
; std/strings/defs-program.lisp.  However, instead of trying to comprehensively
; load the whole string library, we only load a few definitions that we
; actually need.  This helps to avoid horrible circularities in the
; dependencies of various files.

(in-package "XDOC")
(include-book "tools/bstar" :dir :system)
(include-book "std/basic/defs" :dir :system)
(local (include-book "std/util/defredundant" :dir :system))
(local (include-book "make-event/acl2x-help" :dir :system))
; (include-book "std/lists/list-defuns" :dir :system)
(program)
; cert_param (acl2x)
; cert_param (acl2xskip)

; (depends-rec "std/strings/cat" :dir :system)
(acl2::acl2x-replace (include-book
                      "std/strings/cat" :dir :system)
                     (value-triple :invisible)
                     :outside-certification
                     (include-book
                      "std/strings/cat" :dir :system))

; (depends-rec "std/strings/case-conversion" :dir :system)
(acl2::acl2x-replace (include-book
                      "std/strings/case-conversion" :dir :system)
                     (value-triple :invisible)
                     :outside-certification
                     (include-book
                      "std/strings/case-conversion" :dir :system))

; (depends-rec "std/strings/strsubst" :dir :system)
(acl2::acl2x-replace (include-book
                      "std/strings/strsubst" :dir :system)
                     (value-triple :invisible)
                     :outside-certification
                     (include-book
                      "std/strings/strsubst" :dir :system))

; (depends-rec "std/strings/decimal" :dir :system)
(acl2::acl2x-replace (include-book
                      "std/strings/decimal" :dir :system)
                     (value-triple :invisible)
                     :outside-certification
                     (include-book
                      "std/strings/decimal" :dir :system))

(program)

(make-event
 (b* ((events (std::defredundant-fn '(str::cat
                                      str::implode
                                      acl2::implode$inline
                                      str::explode
                                      acl2::explode$inline
                                      str::rchars-to-string
                                      str::fast-concatenate
                                      str::fast-string-append
                                      str::fast-string-append-lst
                                      str::revappend-chars-aux
                                      str::revappend-chars
                                      str::revappend-chars$inline
                                      str::little-a
                                      str::little-z
                                      str::big-a
                                      str::big-z
                                      str::down-alpha-p
                                      str::down-alpha-p$inline
                                      str::up-alpha-p
                                      str::up-alpha-p$inline
                                      str::charlist-has-some-up-alpha-p
                                      str::charlist-has-some-down-alpha-p
                                      str::string-has-some-down-alpha-p
                                      str::string-has-some-up-alpha-p
                                      str::case-delta
                                      str::downcase-char
                                      str::downcase-char$inline
                                      str::downcase-charlist-aux
                                      str::downcase-charlist
                                      str::downcase-string-aux
                                      str::downcase-string
                                      str::upcase-char
                                      str::upcase-char$inline
                                      str::upcase-charlist-aux
                                      str::upcase-charlist
                                      str::upcase-string-aux
                                      str::upcase-string
                                      str::strprefixp-impl
                                      str::strsubst-aux
                                      str::strsubst
                                      str::make-upcase-first-strtbl
                                      str::*upcase-first-strtbl*
                                      str::upcase-first-charlist
                                      str::upcase-char-str$inline
                                      str::upcase-char-str
                                      str::upcase-first
                                      str::join-aux
                                      str::join
                                      str::join$inline
                                      str::basic-natchars
                                      str::natchars-aux
                                      str::natchars
                                      str::natchars$inline
                                      str::natstr
                                      str::natstr$inline
                                      )
                t
                state)))
   (acl2::value events)))


(defun simple-html-encode-chars (x acc)

; X is a character list that we copy into acc (in reverse order), except that
; we escape any HTML entities like < into the &lt; format.

  (b* (((when (atom x))
        acc)
       (acc (case (car x)
              (#\< (list* #\; #\t #\l #\& acc))         ;; "&lt;" (in reverse)
              (#\> (list* #\; #\t #\g #\& acc))         ;; "&gt;"
              (#\& (list* #\; #\p #\m #\a #\& acc))     ;; "&amp;"
              (#\" (list* #\; #\t #\o #\u #\q #\& acc)) ;; "&quot;"
              (t   (cons (car x) acc)))))
    (simple-html-encode-chars (cdr x) acc)))

#||
(reverse (implode (simple-html-encode-chars '(#\a #\< #\b) nil)))
(reverse (implode (simple-html-encode-chars '(#\a #\> #\b) nil)))
(reverse (implode (simple-html-encode-chars '(#\a #\& #\b) nil)))
(reverse (implode (simple-html-encode-chars '(#\a #\" #\b) nil)))
||#

(defun simple-html-encode-str (x n xl acc)

; Revappend the HTML encoding of X (e.g., & --> &amp;) onto ACC.

  (b* (((when (int= n xl))
        acc)
       (char1 (char x n))
       (acc   (case char1
                (#\< (list* #\; #\t #\l #\& acc))         ;; "&lt;" (in reverse)
                (#\> (list* #\; #\t #\g #\& acc))         ;; "&gt;"
                (#\& (list* #\; #\p #\m #\a #\& acc))     ;; "&amp;"
                (#\" (list* #\; #\t #\o #\u #\q #\& acc)) ;; "&quot;"
                (t   (cons char1 acc)))))
    (simple-html-encode-str x (+ 1 n) xl acc)))
