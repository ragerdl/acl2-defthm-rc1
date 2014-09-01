; Standard Association Lists Library
; Copyright (C) 2013 Centaur Technology
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
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "ACL2")
(include-book "xdoc/top" :dir :system)
(include-book "std/lists/list-defuns" :dir :system)

(defsection alist-keys
  :parents (std/alists strip-cars)
  :short "@(call alist-keys) collects all keys bound in an alist."

  :long "<p>This is a \"modern\" equivalent of @(see strip-cars), which
properly respects the non-alist convention; see @(see std/alists) for
discussion of this convention.</p>

<p>Note that the list of keys returned by @('alist-keys') may contain
duplicates.  This happens whenever the input alist contains \"shadowed\"
bindings, as in @('((a . 1) (a . 2))').</p>

<h4>Note about Normal Forms</h4>

<p>A key is a among the @('alist-keys') of an alist exactly when @(see
hons-assoc-equal) is non-nil.  We generally prefer @('hons-assoc-equal') as the
normal form, so the following rule is <b>enabled by default:</b>:</p>

@(thm alist-keys-member-hons-assoc-equal)

<p>However, sometimes the @('member')-based normal form works better when you
want to tie into powerful set-reasoning strategies.  To support this, the
following rule is available but is <b>disabled by default</b>:</p>

@(thm hons-assoc-equal-iff-member-alist-keys)

<p>Obviously these two rules loop, so a @(see theory-invariant) insists that
you choose one or the other.  For greater compatibility between books, please
do not non-@(see local)ly switch the normal form.</p>"

  (defund alist-keys (x)
    (declare (xargs :guard t))
    (cond ((atom x)
           nil)
          ((atom (car x))
           (alist-keys (cdr x)))
          (t
           (cons (caar x) (alist-keys (cdr x))))))

  (local (in-theory (enable alist-keys)))

  (defthm alist-keys-when-atom
    (implies (atom x)
             (equal (alist-keys x)
                    nil)))

  (defthm alist-keys-of-cons
    (equal (alist-keys (cons a x))
           (if (atom a)
               (alist-keys x)
             (cons (car a) (alist-keys x)))))

  (encapsulate
    ()
    (local (defthmd l0
             (equal (alist-keys (list-fix x))
                    (alist-keys x))
             :hints(("Goal" :in-theory (enable list-fix)))))

    (defcong list-equiv equal (alist-keys x) 1
      :hints(("Goal"
              :in-theory (enable list-equiv)
              :use ((:instance l0 (x x))
                    (:instance l0 (x acl2::x-equiv)))))))


  (defthm true-listp-of-alist-keys
    (true-listp (alist-keys x))
    :rule-classes :type-prescription)

  (defthm alist-keys-of-hons-acons
    ;; Silly, but just in case someone disables hons-acons
    (equal (alist-keys (hons-acons key val x))
           (cons key (alist-keys x))))

  (defthm alist-keys-of-pairlis$
    (equal (alist-keys (pairlis$ keys vals))
           (list-fix keys))
    :hints(("Goal" :in-theory (enable list-fix))))

  (defthm alist-keys-member-hons-assoc-equal
    (iff (member-equal x (alist-keys a))
         (hons-assoc-equal x a))
    :hints(("Goal" :in-theory (enable hons-assoc-equal))))

  (defthmd hons-assoc-equal-iff-member-alist-keys
    (iff (hons-assoc-equal x a)
         (member-equal x (alist-keys a)))
    :hints (("goal" :in-theory (enable alist-keys-member-hons-assoc-equal))))

  (theory-invariant (incompatible (:rewrite alist-keys-member-hons-assoc-equal)
                                  (:rewrite hons-assoc-equal-iff-member-alist-keys)))


  (defthmd hons-assoc-equal-when-not-member-alist-keys
    ;; BOZO any reason to have this one?  It's disabled at least, so BOZO check
    ;; if it's ever used and just delete it, if not.
    (implies (not (member-equal x (alist-keys a)))
             (equal (hons-assoc-equal x a)
                    nil))
    :hints (("goal" :in-theory (enable alist-keys-member-hons-assoc-equal))))

  (defthm alist-keys-of-append
    (equal (alist-keys (append x y))
           (append (alist-keys x)
                   (alist-keys y))))

  (defthm alist-keys-of-rev
    (equal (alist-keys (rev x))
           (rev (alist-keys x)))
    :hints(("Goal" :in-theory (enable rev))))

  (defthm alist-keys-of-revappend
    (equal (alist-keys (revappend x y))
           (revappend (alist-keys x)
                      (alist-keys y)))))
