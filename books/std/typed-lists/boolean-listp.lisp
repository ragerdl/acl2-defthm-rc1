; Standard Typed Lists Library
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
(include-book "std/util/deflist" :dir :system)

(in-theory (disable boolean-listp
                    ;; This is an extremely weird built-in forward chaining
                    ;; rule, which seems very unlikely to be useful given the
                    ;; built-in rewrite rule BOOLEAN-LISTP-CONS, so we go ahead
                    ;; and disable it.
                    boolean-listp-forward))

(defsection std/typed-lists/boolean-listp
  :parents (std/typed-lists boolean-listp)
  :short "Lemmas about @(see boolean-listp) available in the @(see
std/typed-lists) library."
  :long "<p>Most of these are generated automatically with @(see
std::deflist).</p>"

  (std::deflist boolean-listp (x)
                (booleanp x)
                :true-listp t
                :elementp-of-nil t
                :already-definedp t
                ;; Set :parents to nil to avoid overwriting the built-in ACL2 documentation
                :parents nil
                :verbosep t
                ;; Gross, horrible hack because ACL2 knows too much about booleanp and our
                ;; usual set of hints doesn't work
                :theory-hack
                ((local (in-theory (enable booleanp boolean-listp)))))

  (in-theory (disable
              ;; We disable this because ACL2 has a built-in rule BOOLEAN-LISTP-CONS
              ;; which is the same thing.
              boolean-listp-of-cons))

  (defthm boolean-listp-of-remove-equal
    ;; BOZO probably add to deflist
    (implies (boolean-listp x)
             (boolean-listp (remove-equal a x))))

  (defthm boolean-listp-of-make-list-ac
    (equal (boolean-listp (make-list-ac n x ac))
           (and (boolean-listp ac)
                (or (booleanp x)
                    (zp n)))))

  (defthm eqable-listp-when-boolean-listp
    (implies (boolean-listp x)
             (eqlable-listp x)))

  (defthm symbol-listp-when-boolean-listp
    (implies (boolean-listp x)
             (symbol-listp x))))


