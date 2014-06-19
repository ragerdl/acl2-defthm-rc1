; Standard Utilities Library
; Copyright (C) 2008-2014 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
;
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "STD")
(include-book "../defines")
(include-book "../deflist")


(defun foo (x)
  (declare (xargs :guard (natp x) :mode :logic))
  x)

(defun bar (x)
  (declare (xargs :guard (natp x)))
  x)


(defines basic
  :parents (hi)
  :short "some dumb thing"
  (define my-evenp ((x natp))
    :short "it's just evenp"
    (if (zp x)
        t
      (my-oddp (- x 1))))
  (define my-oddp (x)
    :guard (natp x)
    (if (zp x)
        nil
      (my-evenp (- x 1)))))

(defines basic2
  :parents (hi)
  :short "some dumb thing"
  (define bool-evenp ((x natp))
    :parents (append)
    :short "Woohoo!"
    :returns (evenp booleanp)
    (if (zp x)
        t
      (bool-oddp (- x 1))))
  (define bool-oddp (x)
    :guard (natp x)
    (if (zp x)
        nil
      (bool-evenp (- x 1)))))

(local (xdoc::set-default-parents foo))

(defines basic3
;  :parents (hi)
  :short "some dumb thing"
  (define basic3 ((x natp))
    :long "<p>goofy merged docs</p>"
    :returns (evenp booleanp)
    (if (zp x)
        t
      (basic3-oddp (- x 1))))
  (define basic3-oddp (x)
    :guard (natp x)
    (if (zp x)
        nil
      (basic3 (- x 1)))))


(defines spurious3
  (define my-oddp3 (x)
    :guard (natp x)
    (if (zp x)
        nil
      (my-evenp3 (- x 1))))
  (define my-evenp3 (x)
    :guard (natp x)
    (if (zp x)
        t
      (if (eql x 1)
          nil
        (my-evenp3 (- x 2))))))

(defines bogus-test
  :bogus-ok t
  (define my-oddp4 (x)
    :guard (natp x)
    (if (zp x)
        nil
      (evenp (- x 1))))
  (define my-evenp4 (x)
    :guard (natp x)
    (if (zp x)
        t
      (if (eql x 1)
          nil
        (my-evenp4 (- x 2))))))

(defines xarg-test
  :verify-guards nil
  :bogus-ok t
  (define my-oddp5 (x)
    :guard (consp x) ;; not valid
    (if (zp x)
        nil
      (evenp (- x 1))))
  (define my-evenp5 (x)
    :guard (natp x)
    (if (zp x)
        t
      (if (eql x 1)
          nil
        (my-evenp5 (- x 2))))))

(defines my-termp

  (define my-termp (x)
    (if (atom x)
        (natp x)
      (and (symbolp (car x))
           (my-term-listp (cdr x))))
    ///
    (defthm natp-when-my-termp
      (implies (atom x)
               (equal (my-termp x)
                      (natp x))))

    (defthm my-termp-of-cons
      (equal (my-termp (cons fn args))
             (and (symbolp fn)
                  (my-term-listp args)))))

  (define my-term-listp (x)
    (if (atom x)
        t
      (and (my-termp (car x))
           (my-term-listp (cdr x))))
    ///
    (deflist my-term-listp (x)
      (my-termp x)
      :already-definedp t)))

(defines my-flatten-term
  :returns-no-induct t
  (define my-flatten-term ((x my-termp))
    :flag term
    :returns (numbers true-listp :rule-classes :type-prescription)
    (if (atom x)
        (list x)
      (my-flatten-term-list (cdr x))))

  (define my-flatten-term-list ((x my-term-listp))
    :flag list
    :returns (numbers true-listp :rule-classes :type-prescription)
    (if (atom x)
        nil
      (append (my-flatten-term (car x))
              (my-flatten-term-list (cdr x)))))
  ///
  (defthm-my-flatten-term-flag
    (defthm nat-listp-of-my-flatten-term
      (implies (my-termp x)
               (nat-listp (my-flatten-term x)))
      :flag term)
    (defthm nat-listp-of-my-flatten-term-list
      (implies (my-term-listp x)
               (nat-listp (my-flatten-term-list x)))
      :flag list)))

(defines my-flatten-term2
  :returns-hints (("goal" :in-theory (disable nat-listp)))
  (define my-flatten-term2 ((x my-termp))
    :flag term
    :returns (numbers nat-listp :hyp :guard
                      :hints ((and stable-under-simplificationp
                                   '(:in-theory (enable nat-listp)))))
    (if (atom x)
        (list x)
      (my-flatten-term2-list (cdr x))))

  (define my-flatten-term2-list ((x my-term-listp))
    :flag list
    :returns (numbers nat-listp :hyp :guard
                      :hints ((and stable-under-simplificationp
                                   '(:in-theory (enable nat-listp)))))
    (if (atom x)
        nil
      (append (my-flatten-term2 (car x))
              (my-flatten-term2-list (cdr x))))))


;; BOZO try to get this working eventually

;; (defines doc-test
;;   :short "Test of local stuff."
;;   :returns-hints (("goal" :in-theory (disable nat-listp)))
;;   (define doc-test ((x my-termp))
;;     :flag term
;;     :returns (numbers nat-listp :hyp :guard
;;                       :hints ((and stable-under-simplificationp
;;                                    '(:in-theory (enable nat-listp)))))
;;     (if (atom x)
;;         (list x)
;;       (doc-test-list (cdr x)))
;;     ///
;;     (local (defthm local1 (integerp (len x))))
;;     (defthm global1 (integerp (len x))))

;;   (define doc-test-list ((x my-term-listp))
;;     :flag list
;;     :returns (numbers nat-listp :hyp :guard
;;                       :hints ((and stable-under-simplificationp
;;                                    '(:in-theory (enable nat-listp)))))
;;     (if (atom x)
;;         nil
;;       (append (doc-test (car x))
;;               (doc-test-list (cdr x)))))

;;   ///
;;   (local (defthm local2 (integerp (len x))))
;;   (defthm global2 (integerp (len x))))

;; (include-book "str/substrp" :dir :system)
;; (include-book "misc/assert" :dir :system)

;; (assert!
;;  (let ((long (cdr (assoc :long (xdoc::find-topic 'doc-test (xdoc::get-xdoc-table (w state)))))))
;;    (and (or (str::substrp "GLOBAL1" long)
;;             (er hard? 'doc-test "Missing global1"))
;;         (or (str::substrp "GLOBAL2" long)
;;             (er hard? 'doc-test "Missing global2"))
;;         (or (not (str::substrp "LOCAL1" long))
;;             (er hard? 'doc-test "Accidentally have local1"))
;;         (or (not (str::substrp "LOCAL2" long))
;;             (er hard? 'doc-test "Accidentally have local2")))))





;; (DEFINES-FN
;;       'DOC-TEST
;;       '(:SHORT
;;             "Test of local stuff." :RETURNS-HINTS
;;             (("goal" :IN-THEORY (DISABLE NAT-LISTP)))
;;             (DEFINE DOC-TEST ((X MY-TERMP))
;;                     :FLAG TERM :RETURNS
;;                     (NUMBERS NAT-LISTP
;;                              :HYP :GUARD
;;                              :HINTS ((AND STABLE-UNDER-SIMPLIFICATIONP
;;                                           '(:IN-THEORY (ENABLE NAT-LISTP)))))
;;                     (IF (ATOM X)
;;                         (LIST X)
;;                         (DOC-TEST-LIST (CDR X)))
;;                     ///
;;                     (LOCAL (DEFTHM LOCAL1 (INTEGERP (LEN X))))
;;                     (DEFTHM GLOBAL1 (INTEGERP (LEN X))))
;;             (DEFINE DOC-TEST-LIST ((X MY-TERM-LISTP))
;;                     :FLAG LIST :RETURNS
;;                     (NUMBERS NAT-LISTP
;;                              :HYP :GUARD
;;                              :HINTS ((AND STABLE-UNDER-SIMPLIFICATIONP
;;                                           '(:IN-THEORY (ENABLE NAT-LISTP)))))
;;                     (IF (ATOM X)
;;                         NIL
;;                         (APPEND (DOC-TEST (CAR X))
;;                                 (DOC-TEST-LIST (CDR X)))))
;;             ///
;;             (LOCAL (DEFTHM LOCAL2 (INTEGERP (LEN X))))
;;             (DEFTHM GLOBAL2 (INTEGERP (LEN X))))
;;       (W STATE))



;; (defsection-progn foo
;;   :short "Foo"
;;   (local (defthm local-lemma (integerp (len x))))
;;   (defthm global-lemma (integerp (len x))))


;; (encapsulate nil
;;   (progn (defun fsdfs (x) x) (local (defun asdf (x) x)))
;;   (local (make-event (let ((state (f-put-global 'old-w (w state) state)))
;;                        (value '(value-triple :foo))))))