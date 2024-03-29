; VL Verilog Toolkit
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

(in-package "VL")
(include-book "../mlib/ctxexprs")
(include-book "../mlib/writer")
(include-book "../mlib/strip")
(local (include-book "../util/arithmetic"))

(defxdoc leftright-check
  :parents (checkers)
  :short "Check for strange expressions like @('A [op] A')."

  :long "<p>This is a heuristic for generating warnings, inspired by PVS
Studio.  It has found a few pretty minor things that we were able to clean up,
and also found one interesting copy/paste bug.</p>

<p>We look for identical sub-expressions on the left and right of most binary
operations, for instance @('A | A') and @('A == A').  It is usually pretty
strange to write such an expression, and sometimes these indicate copy/paste
errors.  We do similar checking for the then- and else-branches of @('?:')
operators.</p>

<p>We also look for part-selects that use the same expressions for both
indices, e.g., @('foo[3:3]'), but these are somewhat more common and minor, and
sometimes result from macros or parameterized modules, so we generally think
these are pretty minor and uninteresting.</p>")

(local (xdoc::set-default-parents leftright-check))

(defenum vl-op-ac-p
  (:vl-binary-plus
   :vl-binary-times
   :vl-binary-eq
   :vl-binary-neq
   :vl-binary-ceq
   :vl-binary-cne
   :vl-binary-logand
   :vl-binary-logor
   :vl-binary-bitand
   :vl-binary-bitor
   :vl-binary-xor
   :vl-binary-xnor)
  :short "Recognizes the associative/commutative binary @(see vl-op-p)s.")

(defthm vl-op-p-when-vl-op-ac-p
  (implies (vl-op-ac-p x)
           (vl-op-p x))
  :hints(("Goal" :in-theory (enable vl-op-ac-p))))

(defthm vl-op-arity-when-vl-op-ac-p
  (implies (vl-op-ac-p x)
           (equal (vl-op-arity x) 2))
  :hints(("Goal" :in-theory (enable vl-op-ac-p))))

(define vl-collect-ac-args
  :short "Collect the nested arguments to an associative/commutative operator."
  ((op vl-op-ac-p "An associative and commutative binary operators.")
   (x  vl-expr-p  "An expression, typically it is an argument to @('op')."))
  :returns (args vl-exprlist-p :hyp :guard)
  :measure (vl-expr-count x)
  :long "<p>If @('x') is itself an @('op') expression, we recursively collect
up the ac-args of its sub-expressions.  Otherwise we just collect @('x').  For
instance, if @('op') is @('|') and @('x') is:</p>

@({
 (a | (b + c)) | (d & e)
})

<p>Then we return a list with three expressions: @('a'), @('b + c'), and @('d &
e').</p>"

  (b* (((when (vl-fast-atom-p x))
        (list x))
       ((unless (eq (vl-nonatom->op x) op))
        (list x))
       ((when (mbe :logic (atom x)
                   :exec nil))
        (impossible))
       (args (vl-nonatom->args x)))
    (append (vl-collect-ac-args op (first args))
            (vl-collect-ac-args op (second args)))))

(defines vl-expr-leftright-check
  :short "Search for strange expressions like @('A [op] A')."
  :long "<p>We search through the expression @('x') for sub-expressions of the
form @('A [op] A'), and generate a warning whenever we find one.  The @('ctx')
is a @(see vl-context-p) that says where @('x') occurs, for more helpful
warnings.  We also use it to suppress warnings in certain cases.</p>"

  (define vl-expr-leftright-check ((x   vl-expr-p)
                                   (ctx vl-context-p))
    :measure (vl-expr-count x)
    ;; :hints(("Goal" :in-theory (disable (force))))))
    :returns (warnings vl-warninglist-p)
    (b* (((when (vl-fast-atom-p x))
          nil)
         (op   (vl-nonatom->op x))
         (args (vl-nonatom->args x))

         ((when (and (eq op :vl-binary-minus)
                     (member (tag (vl-context->elem ctx)) '(:vl-vardecl))
                     (equal (vl-expr-strip (first args))
                            (vl-expr-strip (second args)))
                     (vl-expr-resolved-p (first args))))
          ;; Special hack: Don't warn about things like 5 - 5 in the context
          ;; of net/reg/var declarations.  This can happen for things like:
          ;;   wire bar[`FOO_MSB-`FOO_LSB:0] = baz[`FOO_MSB:`FOO_LSB]
          ;; and leads to a lot of spurious warnings.
          nil)

         ((when (vl-op-ac-p op))
          ;; For associative commutative ops, collect up all the args and
          ;; see if there are any duplicates.
          (b* ((subexprs     (append (vl-collect-ac-args op (first args))
                                     (vl-collect-ac-args op (second args))))
               (subexprs-fix (vl-exprlist-strip subexprs))
               (dupes        (duplicated-members subexprs-fix))
               ((when dupes)
                (cons (make-vl-warning
                       :type :vl-warn-leftright
                       :msg "~a0: found an ~s1 expression with duplicated ~
                              arguments, which is ~s2: ~s3"
                       :args (list ctx
                                   (vl-op-string op)
                                   (if (eq op :vl-binary-plus)
                                       "somewhat odd (why not use wiring to double it?)"
                                     "odd")
                                   (with-local-ps (vl-pp-exprlist dupes)))
                       :fatalp nil
                       :fn __function__)
                      ;; This can result in a pile of redundant warnings, but
                      ;; whatever.  A better alternative would be to recur on
                      ;; subexprs, but then we'd have to argue about the
                      ;; acl2-count of collect-ac-args.... ugh.
                      (vl-exprlist-leftright-check args ctx))))
            ;; Else, no dupes; fine, keep going.
            (vl-exprlist-leftright-check args ctx)))

         ((when (and (member op (list :vl-binary-minus :vl-binary-div :vl-binary-rem
                                      :vl-binary-lt :vl-binary-lte
                                      :vl-binary-gt :vl-binary-gte

                                      ;; There's no reason that these are
                                      ;; necessarily wrong, but it still seems
                                      ;; kind of weird so I include them
                                      :vl-binary-shr :vl-binary-shl
                                      :vl-binary-ashr :vl-binary-ashl))
                     (equal (vl-expr-strip (first args))
                            (vl-expr-strip (second args)))))
          (cons (make-vl-warning
                 :type :vl-warn-leftright
                 :msg "~a0: found an expression of the form FOO ~s1 FOO, which is ~s2: ~a3."
                 :args (list ctx (vl-op-string op)
                             (if (eq op :vl-binary-plus)
                                 "somewhat odd (why not use wiring to double it?)"
                               "odd")
                             x)
                 :fatalp nil
                 :fn __function__)
                (vl-exprlist-leftright-check args ctx)))

         ((when (and (member op '(:vl-partselect-colon))
                     (equal (vl-expr-strip (second args))
                            (vl-expr-strip (third args)))))
          (cons (make-vl-warning
                 :type :vl-warn-partselect-same
                 :msg "~a0: slightly odd to have a part-select with the same indices: ~a1."
                 :args (list ctx x)
                 :fatalp nil
                 :fn __function__)
                ;; Note: we might want to not recur here, for similar reasons to the
                ;; special hack above for minuses in net/reg/var decls.
                (vl-exprlist-leftright-check args ctx)))

         ((when (and (member op '(:vl-qmark))
                     (equal (vl-expr-strip (second args))
                            (vl-expr-strip (third args)))))
          (cons (make-vl-warning
                 :type :vl-warn-leftright
                 :msg "~a0: found an expression of the form FOO ? BAR : BAR, which is odd: ~a1."
                 :args (list ctx x)
                 :fatalp nil
                 :fn __function__)
                (vl-exprlist-leftright-check args ctx))))

      (vl-exprlist-leftright-check args ctx)))

  (define vl-exprlist-leftright-check ((x vl-exprlist-p)
                                       (ctx vl-context-p))
    :measure (vl-exprlist-count x)
    :returns (warnings vl-warninglist-p)
    (if (atom x)
        nil
      (append (vl-expr-leftright-check (car x) ctx)
              (vl-exprlist-leftright-check (cdr x) ctx)))))


(define vl-exprctxalist-leftright-check
  :short "@(call vl-exprctxalist-leftright-check) extends @(see
vl-expr-leftright-check) across an @(see vl-exprctxalist-p)."
  ((x vl-exprctxalist-p))
  :returns (warnings vl-warninglist-p)
  (if (atom x)
      nil
    (append (vl-expr-leftright-check (caar x) (cdar x))
            (vl-exprctxalist-leftright-check (cdr x)))))

(define vl-module-leftright-check
  :short "@(call vl-module-leftright-check) carries our our @(see
leftright-check) on all the expressions in a module, and adds any resulting
warnings to the module."
  ((x vl-module-p))
  :returns (new-x vl-module-p :hyp :fguard)
  (b* ((ctxexprs     (vl-module-ctxexprs x))
       (new-warnings (vl-exprctxalist-leftright-check ctxexprs)))
    (change-vl-module x
                      :warnings (append new-warnings
                                        (vl-module->warnings x)))))

(defprojection vl-modulelist-leftright-check (x)
  (vl-module-leftright-check x)
  :guard (vl-modulelist-p x)
  :result-type vl-modulelist-p)

(define vl-design-leftright-check ((x vl-design-p))
  :returns (new-x vl-design-p)
  (b* ((x (vl-design-fix x))
       ((vl-design x) x))
    (change-vl-design x :mods (vl-modulelist-leftright-check x.mods))))





