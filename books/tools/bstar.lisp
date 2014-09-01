; b* -- pluggable sequencing/binding macro thing
; Copyright (C) 2007-2014 Centaur Technology
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
; Original author: Sol Swords <sswords@centtech.com>

(in-package "ACL2")
(include-book "xdoc/base" :dir :system)

(defxdoc b*
  :parents (macro-libraries)
  :short "The @('b*') macro is a replacement for @(see let*) that adds support
for multiple return values, mixing control flow with binding, causing side
effects, introducing type declarations, and doing other kinds of custom pattern
matching."

  :long "<h3>Introduction</h3>

<p>To use @('b*') you will need to load the following book:</p>

@({
    (include-book \"tools/bstar\" :dir :system)
})

<p>In its most basic form, the @('b*') macro is nearly a drop-in replacement
for @(see let*).  For instance, these are equivalent:</p>

@({
    (let* ((x 1)               (b* ((x 1)
           (y 2)          ==        (y 2)
           (z (+ x y)))             (z (+ x y)))
      (list x y z))              (list x y z))
})

<p>But beyond simple variable bindings, @('b*') provides many useful, extended
@(see b*-binders).  A simple example is the <see topic='@(url patbind-mv)'>mv
binder</see>, which can nicely avoid switching between @(see let*) and @(see
mv-let).  For instance:</p>

@({
   (let* ((parts (get-parts args)))            (b* ((parts (get-parts args))
     (mv-let (good bad)                   ==       ((mv good bad) (split-parts parts))
       (split-parts parts)                         (new-good (mark-good good))
       (let* ((new-good (mark-good good))          (new-bad  (mark-bad bad)))
              (new-bad  (mark-bad bad)))         (append new-good new-bad))
         (append new-good new-bad))))
})

<p>Another interesting example is the <see topic='@(url patbind-when)'>when
binder</see>, which allows for a sort of \"early exit\" from the @('b*') form
without needing to alternate between @('let*') and @('if').  For instance:</p>

@({
  (let* ((sum (get-sum (car x))))       (b* ((sum (get-sum (car x)))
    (if (< sum limit)               ==       ((when (< sum limit))
        ans                                   ans)
      (let* ((ans   (+ ans sum))             (ans   (+ ans sum))
             (limit (+ limit 1)))            (limit (+ limit 1)))
        (fn (cdr x) ans limit))))         (fn (cdr x) ans limit))
})

<p>The only part of the @('let*') syntax that is not available in @('b*') is
the @(see declare) syntax.  However, @('ignore')/@('ignorable') declarations
are available using a different syntax (see below), and @(see type-spec)
declarations are available using the <see topic='@(url patbind-the)'>the
binder.</see></p>


<h3>General Form</h3>

<p>The general syntax of b* is:</p>

@({
     (b* <list-of-bindings> . <list-of-result-forms>)
})

<p>where a <i>result form</i> is any ACL2 term, and a <i>binding</i> is</p>

@({
     (<binder-form> [<expression>])
})

<p>Depending on the binder form, it may be that multiple expressions are
allowed or only a single one.</p>

<p>The @('tools/bstar') book comes with several useful b* binders already
defined, which we describe below.  You can also define your own, custom binder
forms to extend the syntax of @('b*') to provide additional kinds of pattern
matching or to implement common coding patterns.  For example, the @(see
std::defaggregate) macro automatically introduces new @('b*') binders that let
you access the fields of structures using a C-like @('employee.name') style
syntax.</p>

<p>Note: One difference between @('let*') and @('b*') is that @('b*') allows
multiple forms to occur in the body, and returns the value of the last form.
For example:</p>

@({
    (b* ((x 1)
         (y 2)
         (z (+ x y)))
      (cw \"Hello, \")
      (cw \" world!~%\")
      (list x y z))
})

<p>Will print @('Hello, world!') before returning @('(1 2 3)'), whereas putting
these @(see cw) statements into a @(see let*) form would be a syntax error.</p>


<h3>Built-In B* Binders</h3>

<p>Here is a nonsensical example that gives a flavor for the kind of b* binders
that are available \"out of the box.\"</p>

@({
 (b* ( ;; don't forget the first open paren! (like with let*)

      ;; let*-like binding to a single variable:
      (x (cons 'a 'b))

      ;; mv binding
      ((mv y z) (return-two-values x x))

      ;; No binding: expression evaluated for side effects
      (- (cw \"Hello\")) ;; prints \"Hello\"

      ;; Binding with type declaration:
      ((the (integer 0 100) n) (foo z))

      ;; MV which ignores a value:
      ((mv & a) (return-garbage-in-first-mv y z))

      ;; Binds value 0 to C and value 1 to D,
      ;; declares (ignorable C) and (ignore D)
      ((mv ?c ?!d) (another-mv a z))

      ;; Bind V to the middle value of an error triple,
      ;; quitting if there is an error condition (a la er-let*)
      ((er v) (trans-eval '(len (list 'a 1 2 3)) 'foo state))

      ;; The WHEN, IF, and UNLESS constructs insert an IF in the
      ;; binding stream.  WHEN and IF are equivalent.
      ((when v) (finish-early-because-of v))
      ((if v)   (finish-early-because-of v))
      ((unless c) (finish-early-unless c))

      ;; Pattern-based binding using cons, where D is ignorable
      ((cons (cons b c) ?d) (must-return-nested-conses a))

      ;; Patterns based on LIST and LIST* are also supported:
      ((list a b) '((1 2) (3 4)))
      ((list* a (the string b) c) '((1 2) \"foo\" 5 6 7))

      ;; Alternate form of pattern binding with cons nests, where G is
      ;; ignored and F has a type declaration:
      (`(,e (,(the (signed-byte 8) f) . ,?!g))
       (makes-a-list-of-conses b))

      ;; Pattern with user-defined constructor:
      ((my-tuple foo bar hum) (something-of-type-my-tuple e c g))

      ;; Don't-cares with pattern bindings:
      ((my-tuple & (cons carbar &) hum) (something-else foo f hum))

      ;; Pattern inside an mv:
      ((mv a (cons & c)) (make-mv-with-cons))

      ) ;; also don't forget the close-paren after the binder list

   ;; the body (after the binder list) is an implicit PROGN$
   (run-this-for-side-effects ...)
   (return-this-expression .....))
})

<p>We now give some additional details about these built-in binders.  Since
users can also define their own @('b*') binders, you may wish to see @(see
b*-binders) for a more comprehensive list of available binder forms.</p>

<dl>

<dt>@('(mv a b ...)')</dt>
<dd>Produces an @(see mv-let) binding.</dd>

<dt>@('(cons a b)')</dt>
<dd>Binds @('a') and @('b') to @('(car val)') and @('(cdr val)'), respectively,
where @('val') is the result of the corresponding expression.</dd>

<dt>@('(er a)')</dt>
<dd>Produces an ER-LET* binding.</dd>

<dt>@('(list a b ...)')</dt>
<dd>Binds @('a'), @('b'), ... to @('(car val)'), @('(cadr val)'), etc., where
@('val') is the result of the corresponding expression.</dd>

<dt>@('(nths a b ...)')</dt>
<dd>Binds @('a'), @('b'), ... to @('(nth 0 val)'), @('(nth 1 val)'), etc.,
where @('val') is the result of the corresponding expression.  This is very
much like @('list'), but may be useful when @(see nth) is disabled.</dd>

<dt>@('(list* a b)')<br/>
    @('`(,a . ,b)')</dt>
<dd>Alternatives to the @('cons') binder.</dd>

<dt>@('(the type-spec var)')</dt>
<dd>Binds @('var') to the result of the corresponding expression, and adds
a @(see declare) form saying that @('var') is of the given @(see type-spec).
You can nest @('the') patterns inside other patterns, but @('var') must itself
be a symbol instead of a nested pattern, and @('type-spec') must be a valid
@(see type-spec).</dd>

<dt>@('(if test)')<br/>
@('(when test)')<br/>
@('(unless test)')</dt>

<dd>These forms don't actually produce bindings at all.  Instead, they insert\
an @(see if) where one branch is the rest of the @('B*') form and the other is
the \"bound\" expression.  For example,
@({
    (b* (((if (atom a)) 0)
         (rest (of-bindings)))
      final-expr)
})
expands to something like this:
@({
    (if (atom a)
        0
      (b* ((rest (of-bindings)))
        final-expr))
})
These forms can also create an \"implicit progn\" with multiple expressions,
like this:
@({
   (b* (((if (atom a))
         (cw \"a is an atom, returning 0\")
         0)
        ...)
     ...)
})
</dd>

</dl>


<p>Note that the @('cons'), @('list'), @('list*'), and backtick binders may be
nested arbitrarily inside other binders.  User-defined binders may often be
arbitrarily nested.  For example,</p>

@({
     ((mv (list `(,a . ,b)) (cons c d)) <form>)
})

<p>will result in the following (logical) bindings:</p>

<ul>
<li>@('a') bound to @('(car (nth 0 (mv-nth 0 <form>)))')</li>
<li>@('b') bound to @('(cdr (nth 0 (mv-nth 0 <form>)))')</li>
<li>@('c') bound to @('(car (mv-nth 1 <form>))')</li>
<li>@('d') bound to @('(cdr (mv-nth 1 <form>))')</li>
</ul>



<h3>Side Effects and Ignoring Variables</h3>

<p>The following constructs may be used in place of variables</p>

<table>

<tr>
<th>@('-')</th>
<td>Dash (@('-')), used as a top-level binding form, will run the corresponding
expressions (in an implicit progn) for side-effects without binding its value.
Used as a lower-level binding form, it will cause the binding to be ignored or
not created.</td>
</tr>

<tr>
<th>@('&')</th>
<td>Ampersand (@('&')), used as a top-level binding form, will cause the
corresponding expression to be ignored and not run at all.  Used as a
lower-level binding form, it will cause the binding to be ignored or not
created.</td>
</tr>

<tr>
<th>@('?!')</th>
<td>Any symbol beginning with @('?!') works similarly to the @('&') form.  It
is @(see declare)d ignored or not evaluated at all.</td>
</tr>

<tr>
<th>@('?')</th>
<td>Any symbol beginning with @('?') but not @('?!') will make a binding of the symbol
obtained by removing the @('?'), and will make an @('ignorable') declaration for this
variable.</td>
</tr>

</table>


<h3>User-Defined Binders</h3>

<p>B* expands to multiple nestings of another macro, @('PATBIND'), analogously
to how LET* expands to multiple nestings of LET.</p>

<p>New b* binders may be created by defining a macro named @('PATBIND-<name>').
We discuss the detailed interface of user-defined binders below.  But first,
note that @('def-patbind-macro') provides a simple way to define certain user binders.
For example, this form is used to define the binder for CONS:</p>

@({
    (def-patbind-macro cons (car cdr))
})

<p>This defines a binder macro, @('patbind-cons'), which enables @('(cons a
b)') to be used as a binder form.  This binder form must take two arguments
since two destructor functions, @('(car cdr)'), are given to
@('def-patbind-macro').  The destructor functions are each applied to the form
to produce the bindings for the corresponding arguments of the binder.</p>

<p>There are many cases in which @('def-patbind-macro') is not powerful enough.
For example, a binder produced by @('def-patbind-macro') may only take a fixed
number of arguments.  More flexible operations may be defined by hand-defining
the binder macro using the form @(see def-b*-binder).</p>

<p>A binder macro, @('patbind-<name>') must take three arguments: @('args'),
@('forms'), and @('rest-expr').  The form</p>

@({
    (b* (((foo arg1 arg2) binding1 binding2))
      expr)
})

<p>translates to a macro call</p>

@({
     (patbind-foo (arg1 arg2) (binding1 binding2) expr)
})

<p>That is:</p>

<ul>
<li>@('args') is the list of arguments given to the binder form,</li>
<li>@('bindings') is the list of expressions bound to them, and</li>
<li>@('expr') is the result expression to be run once the bindings are in place.</li>
</ul>

<p>The definition of the @('patbind-foo') macro determines how this gets
further expanded.  Some informative examples of these binder macros may be
found in @('tools/bstar.lisp'); simply search for uses of @(see
def-b*-binder).</p>

<p>Here are some further notes on defining binder macros.</p>

<p>Often the simplest way to accomplish the intended effect of a patbind macro
is to have it construct another @('b*') form to be recursively expanded, or to
call other patbind macros.  See, for example, the definition of
@('patbind-list').</p>

<p>Patbind macros for forms that are truly creating bindings should indeed use
@('b*') (or @('patbind'), which is what @('b*') expands to) to create these
bindings, so that ignores and nestings are dealt with uniformly.  See, for
example, the definition of @('patbind-nths').</p>

<p>In order to get good performance, destructuring binders such as are produced
by @('def-patbind-macro') bind a variable to any binding that isn't already a
variable or quoted constant.  This is important so that in the following form,
@('(foo x y)') is run only once:</p>

@({
    (b* (((cons a b) (foo x y))) ...)
})

<p>In these cases, it is good discipline to check the new variables introduced
using the macro @('check-vars-not-free'); since ACL2 does not have gensym, this
is the best option we have. See any definition produced by
@('def-patbind-macro') for examples, and additionally @('patbind-nths'),
@('patbind-er'), and so forth.</p>")

(defxdoc b*-binders
  :parents (b*)
  :short "List of the available directives usable in @('b*')")

(mutual-recursion
 (defun pack-list (args)
   (declare (xargs :measure (acl2-count args)
                   :guard t
                   :verify-guards nil))
   (if (atom args)
       nil
     (if (atom (cdr args))
         (pack-tree (car args))
       (append (pack-tree (car args))
               (cons #\Space
                     (pack-list (cdr args)))))))
 (defun pack-tree (tree)
   (declare (xargs :measure (acl2-count tree)
                   :guard t))
   (if (atom tree)
       (if (or (acl2-numberp tree)
               (characterp tree)
               (stringp tree)
               (symbolp tree))
           (explode-atom tree 10)
         '(#\Space))
     (append (cons #\( (pack-tree (car tree)))
             (cons #\Space (pack-list (cdr tree)))
             (list #\))))))

(defun pack-term (args)
  (declare (xargs :guard t
                  :verify-guards nil))
  (intern (coerce (pack-list args) 'string) "ACL2"))

(defmacro pack (&rest args)
  `(pack-term (list ,@args)))

(defun macro-name-for-patbind (binder)
  (intern-in-package-of-symbol
   (concatenate 'string "PATBIND-" (symbol-name binder))
   (if (equal (symbol-package-name binder) "COMMON-LISP")
       'acl2::foo
     binder)))

(defconst *patbind-special-syms* '(t nil & -))

(defun int-string (n)
  (coerce (explode-nonnegative-integer n 10 nil) 'string))

(defun str-num-sym (str n)
  (intern (concatenate 'string str (int-string n)) "ACL2"))

(defun ignore-var-name (n)
  (str-num-sym "IGNORE-" n))


(defun debuggable-binder-list-p (x)
  (declare (xargs :guard t))
  (cond ((atom x)
         (or (equal x nil)
             (cw "; Not a binder list; ends with ~x0, instead of nil.~%" x)))
        ;; This used to check that the cdar was also a cons and a true-list,
        ;; but this can be left up to the individual binders.
        ((consp (car x))
         (debuggable-binder-list-p (cdr x)))
        (t
         (cw "; Not a binder list; first bad entry is ~x0.~%" (car x)))))

(defun debuggable-binders-p (x)
  (declare (xargs :guard t))
  (cond ((atom x)
         (or (equal x nil)
             (cw "; Not a binder list; ends with ~x0, instead of nil.~%" x)))
        ;; This used to check that the cdar was also a cons and a true-list,
        ;; but this can be left up to the individual binders.
        ((consp (car x)) t)
        (t
         (cw "; Not a binder list; first bad entry is ~x0.~%" (car x)))))

(defun decode-varname-for-patbind (pattern)
  (let* ((name (symbol-name pattern))
         (len (length name))
         (?p (and (<= 1 len)
                  (eql (char name 0) #\?)))
         (?!p (and ?p
                   (<= 2 len)
                   (eql (char name 1) #\!)))
         (sym (cond
               (?!p (intern-in-package-of-symbol
                     (subseq name 2 nil) pattern))
               (?p (intern-in-package-of-symbol
                    (subseq name 1 nil) pattern))
               (t pattern)))
         (ignorep (cond
                   (?!p 'ignore)
                   (?p 'ignorable))))
    (mv sym ignorep)))

(defun patbindfn (pattern assign-exprs nested-expr)
  (cond ((eq pattern '-)
         ;; A dash means "run this for side effects."  In this case we allow
         ;; multiple terms; these form an implicit progn, in the common-lisp sense.
         `(prog2$ (progn$ . ,assign-exprs)
                  ,nested-expr))
        ((member pattern *patbind-special-syms*)
         ;; &, T, NIL mean "don't bother evaluating this."
         nested-expr)
        ((atom pattern)
         ;; A binding to a single variable.  Here we don't allow multiple
         ;; expressions; we believe it's more readable to use - to run things
         ;; for side effects, and this might catch some paren errors.
         (if (cdr assign-exprs)
             (er hard 'b* "~
The B* binding of ~x0 to ~x1 isn't allowed because the binding of a variable must be a
single term." pattern assign-exprs)
           (mv-let (sym ignorep)
             (decode-varname-for-patbind pattern)
             ;; Can we just refuse to bind a variable marked ignored?
             (if (eq ignorep 'ignore)
                 nested-expr
               `(let ((,sym ,(car assign-exprs)))
                  ,@(and ignorep `((declare (,ignorep ,sym))))
                  ,nested-expr)))))
        ((eq (car pattern) 'quote)
         ;; same idea as &, t, nil
         nested-expr)
        (t ;; Binding macro call.
         (let* ((binder (car pattern))
                (patbind-macro (macro-name-for-patbind binder))
                (args (cdr pattern)))
           `(,patbind-macro ,args ,assign-exprs ,nested-expr)))))

(defmacro patbind (pattern assign-exprs nested-expr)
  (patbindfn pattern assign-exprs nested-expr))


;; (defun b*-fn1 (bindlist expr)
;;   (declare (xargs :guard (debuggable-binders-p bindlist)))
;;   (if (atom bindlist)
;;       expr
;;     `(patbind ,(caar bindlist) ,(cdar bindlist)
;;               ,(b*-fn1 (cdr bindlist) expr))))

;; (defun b*-fn (bindlist exprs)
;;   (declare (xargs :guard (and (debuggable-binders-p bindlist)
;;                               (consp exprs))))
;;   (b*-fn1 bindlist `(progn$ . ,exprs)))

(defun b*-fn (bindlist exprs)
  (declare (xargs :guard (and (debuggable-binders-p bindlist)
                              (consp exprs))))
  (if (atom bindlist)
      (cons 'progn$ exprs)
    `(patbind ,(caar bindlist) ,(cdar bindlist)
              (b* ,(cdr bindlist) . ,exprs))))

(defmacro b* (bindlist expr &rest exprs)
  (declare (xargs :guard (debuggable-binders-p bindlist)))
  (b*-fn bindlist (cons expr exprs)))



(defxdoc def-b*-binder
  :parents (b*)
  :short "Introduce a new form usable inside @(see b*)."
  :long "<p>Usage:</p>
@({
    (def-b*-binder name
      [:parents parents]   ;; default: (b*-binders)
      [:short short]
      [:long long]
      :decls declare-forms
      :body body)
})

<p>Introduces a B* binder form of the given name.  The given @('body') may use
the variables @('args'), @('forms'), and @('rest-expr'), and will control how
to macroexpand a form like the following:</p>

@({
 (b* (((<name> . <args>) . <forms>)) <rest-expr>)
})

<p>The documentation forms are optional, and placeholder documentation will be
generated if none is provided.  It is recommended that the parents include
@(see b*-binders) since this provides a single location where the user may see
all of the available binder forms.</p>

<p>This works by introducing a macro named @('patbind-name').  See @(see b*)
for more details.</p>")

(defmacro def-b*-binder (name &key
                              (parents '(b*-binders))
                              short long decls body)
  (let* ((macro-name (macro-name-for-patbind name))
         (short      (or short
                         (concatenate 'string
                                      "@(see b*) binder form @('" (symbol-name name)
                                      "') (placeholder).")))
         (long       (or long
                         (concatenate 'string
                                      "<p>This is a b* binder introduced with @(see def-b*-binder).</p>
                                      @(def " (symbol-name macro-name) ")"))))
    `(progn
       (defxdoc ,macro-name :parents ,parents :short ,short :long ,long)
       (defmacro ,macro-name (args forms rest-expr) ,@decls ,body)
       (table b*-binder-table ',name ',macro-name))))

(defmacro destructure-guard (binder args bindings len)
  `(and (or (and (true-listp ,args)
                 . ,(and len `((= (length ,args) ,len))))
            (cw "~%~%**** ERROR ****
Pattern constructor ~x0 needs a true-list of ~@1arguments, but was given ~x2~%~%"
                ',binder ,(if len `(msg "~x0 " ,len) "")
                ,args))
        (or (and (consp ,bindings)
                 (eq (cdr ,bindings) nil))
            (cw "~%~%**** ERROR ****
Pattern constructor ~x0 needs exactly one binding expression, but was given ~x1~%~%"
                ',binder ,bindings))))

(defun destructor-binding-list (args destructors binding)
  (if (atom args)
      nil
    (cons (list (car args) (list (car destructors) binding))
          (destructor-binding-list (cdr args) (cdr destructors) binding))))

(defmacro def-patbind-macro (binder destructors
                                    &key
                                    (parents '(b*-binders))
                                    short
                                    long)
  `(def-b*-binder ,binder
     :parents ,parents
     :short ,short
     :long ,long
     :decls ((declare (xargs :guard (destructure-guard ,binder args forms ,(len destructors)))))
     :body
     (let* ((binding (car forms))
            (computedp (or (atom binding)
                           (eq (car binding) 'quote)))
            (bexpr (if computedp binding (pack binding)))
            (binders (destructor-binding-list args ',destructors bexpr)))
       (if computedp
           `(b* ,binders ,rest-expr)
         `(let ((,bexpr ,binding))
            (declare (ignorable ,bexpr))
            (b* ,binders
              (check-vars-not-free (,bexpr) ,rest-expr)))))))

;; The arg might be a plain variable, an ignored or ignorable variable, or a
;; binding expression.
(defun var-ignore-list-for-patbind-mv (args igcount mv-vars binders ignores ignorables freshvars)
  (if (atom args)
      (mv (reverse mv-vars)
          (reverse binders)
          (reverse ignores)
          (reverse ignorables)
          (reverse freshvars))
    (mv-let (mv-var binder freshp ignorep)
      (cond ((or (member (car args) *patbind-special-syms*)
                 (quotep (car args))
                 (and (atom (car args)) (not (symbolp (car args)))))
             (let ((var (ignore-var-name igcount)))
               (mv var nil nil 'ignore)))
            ((symbolp (car args))
             (mv-let (sym ignorep)
               (decode-varname-for-patbind (car args))
               (case ignorep
                 (ignore (mv sym nil nil 'ignore))
                 (ignorable (mv sym nil nil 'ignorable))
                 (t (mv sym nil nil nil)))))
            (t ;; (and (consp (car args))
             ;;                   (not (eq (caar args) 'quote)))
             (let ((var (pack (car args))))
               (mv var (list (car args) var) t nil))))
      (var-ignore-list-for-patbind-mv
       (cdr args)
       (if (eq ignorep 'ignore) (1+ igcount) igcount)
       (cons mv-var mv-vars)
       (if binder (cons binder binders) binders)
       (if (eq ignorep 'ignore) (cons mv-var ignores) ignores)
       (if (eq ignorep 'ignorable) (cons mv-var ignorables) ignorables)
       (if freshp (cons mv-var freshvars) freshvars)))))

(def-b*-binder mv
  :short "@(see b*) binder for multiple values."
  :long "<p>Example:</p>

@({
    (b* (((mv a b c) (form-returning-three-values)))
      form)
})

<p>is equivalent to</p>

@({
    (mv-let (a b c)
      (form-returning-three-values)
      form)
})

<p>The @('mv') binder only makes sense as a top-level binding, but each of its
arguments may be a recursive binding.</p>"
  :decls
  ((declare (xargs :guard (destructure-guard mv args forms nil))))
  :body
  (mv-let (vars binders ignores ignorables freshvars)
    (var-ignore-list-for-patbind-mv args 0 nil nil nil nil nil)
    `(mv-let ,vars ,(car forms)
       (declare (ignore . ,ignores))
       (declare (ignorable . ,ignorables))
       (check-vars-not-free
        ,ignores
        (b* ,binders
          (check-vars-not-free ,freshvars ,rest-expr))))))

(def-patbind-macro cons (car cdr)
  :short "@(see b*) binder for decomposing a @(see cons) into its @(see car)
and @(see cdr)."
  :long "<p>Usage:</p>

@({
     (b* (((cons a b) (binding-form)))
       (result-form))
})

<p>is equivalent to</p>

@({
    (let* ((tmp (binding-form))
           (a   (car tmp))
           (b   (cdr tmp)))
      (result-form))
})

<p>Each of the arguments to the @('cons') binder may be a recursive binder, and
@('cons') may be nested inside other bindings.</p>")

(defun nths-binding-list (args n form)
  (if (atom args)
      nil
    (cons (list (car args) `(nth ,n ,form))
          (nths-binding-list (cdr args) (1+ n) form))))

(def-b*-binder nths
  :short "@(see b*) binder for list decomposition, using @(see nth)."
  :long "<p>Usage:</p>
@({
    (b* (((nths a b c) (list-fn ...)))
      form)
})

<p>is equivalent to</p>

@({
    (b* ((tmp (list-fn ...))
         (a   (nth 0 tmp))
         (b   (nth 1 tmp))
         (c   (nth 2 tmp)))
      form)
})

<p>Each of the arguments to the @('nths') binder may be a recursive binder, and
@('nths') may be nested inside other bindings.</p>

<p>This binder is very similar to the @('list') binder, see @(see
patbind-list).  However, here we put in explicit calls of @('nth'), whereas the
@('list') binder will put in, e.g., @('car'), @('cadr'), etc.  The @('list')
binder is likely to be more efficient in general, but the @('nths') binder may
occasionally be useful when you have @('nth') disabled.</p>"

  :decls
  ((declare (xargs :guard (destructure-guard nths args forms nil))))

  :body
  (let* ((binding (car forms))
         (evaledp (or (atom binding) (eq (car binding) 'quote)))
         (form (if evaledp binding (pack binding)))
         (binders (nths-binding-list args 0 form)))
    (if evaledp
        `(b* ,binders ,rest-expr)
      `(let ((,form ,binding))
         (declare (ignorable ,form))
         (b* ,binders
           (check-vars-not-free (,form) ,rest-expr))))))

(def-b*-binder nths*
  :short "@(see b*) binder for list decomposition, using @(see nth), with one
final @(see nthcdr)."

  :long "<p>Usage:</p>
@({
    (b* (((nths* a b c d) (list-fn ...)))
      form)
})

<p>is equivalent to</p>

@({
    (b* ((tmp (list-fn ...))
         (a   (nth 0 tmp))
         (b   (nth 1 tmp))
         (c   (nth 2 tmp))
         (d   (nthcdr 3 tmp)))
      form)
})

<p>Each of the arguments to the @('nths*') binder may be a recursive binder,
and @('nths*') may be nested inside other bindings.</p>

<p>This binder is very similar to the @('list*') binder, see @(see
patbind-list*).  However, here we put in explicit calls of @('nth') and
@('nthcdr'), whereas the @('list*') binder will put in, e.g., @('car'),
@('cadr'), etc.  The @('list*') binder is likely to be more efficient in
general, but the @('nths*') binder may occasionally be useful when you have
@('nth') disabled.</p>"

  :decls
  ((declare (xargs :guard (and (destructure-guard nths args forms nil)
                               (< 0 (len args))))))
  :body
  (let* ((binding (car forms))
         (evaledp (or (atom binding) (eq (car binding) 'quote)))
         (form (if evaledp binding (pack binding)))
         (binders (append (nths-binding-list (butlast args 1) 0 form)
                          `((,(car (last args)) (nthcdr ,(1- (len args)) ,form))))))
    (if evaledp
        `(b* ,binders ,rest-expr)
      `(let ((,form ,binding))
         (declare (ignorable ,form))
         (b* ,binders
           (check-vars-not-free (,form) ,rest-expr))))))

(def-b*-binder list
  :short "@(see b*) binder for list decomposition, using @(see car)/@(see cdr)."
  :long "<p>Usage:</p>
@({
     (b* (((list a b c) lst))
       form)
})

<p>is equivalent to</p>

@({
    (b* ((a (car lst))
         (tmp1 (cdr lst))
         (b (car tmp1))
         (tmp2 (cdr tmp1))
         (c (car tmp2)))
      form)
})

<p>Each of the arguments to the @('list') binder may be a recursive binder, and
@('list') may be nested inside other bindings.</p>"
  :decls
  ((declare (xargs :guard (destructure-guard list args forms nil))))
  :body
  (if (atom args)
      rest-expr
    `(patbind-cons (,(car args) (list . ,(cdr args))) ,forms ,rest-expr)))

(def-b*-binder list*
  :short "@(see b*) binder for @('list*') decomposition using @(see car)/@(see cdr)."
  :long "<p>Usage:</p>
@({
    (b* (((list* a b c) lst)) form)
})

<p>is equivalent to</p>

@({
    (b* ((a (car lst))
         (tmp1 (cdr lst))
         (b (car tmp1))
         (c (cdr tmp1)))
      form)
})

<p>Each of the arguments to the @('list*') binder may be a recursive binder,
and @('list*') may be nested inside other bindings.</p>"
  :decls
  ((declare (xargs :guard (and (consp args)
                               (destructure-guard list* args forms nil)))))
  :body
  (if (atom (cdr args))
      `(patbind ,(car args) ,forms ,rest-expr)
    `(patbind-cons (,(car args) (list* . ,(cdr args))) ,forms ,rest-expr)))

(defun assigns-for-assocs (args alist)
  (if (atom args)
      nil
    (cons (if (consp (car args))
              `(,(caar args) (cdr (assoc ,(cadar args) ,alist)))
            (mv-let (sym ign)
              (decode-varname-for-patbind (car args))
              (declare (ignore ign))
              `(,(car args) (cdr (assoc ',sym ,alist)))))
          (assigns-for-assocs (cdr args) alist))))

(def-b*-binder assocs
  :short "@(see b*) binder for extracting particular values from an alist."
  :long "<p>Usage:</p>
@({
    (b* (((assocs (a akey) b (c 'foo)) alst))
      form)
})

<p>is equivalent to</p>

@({
    (b* ((a (cdr (assoc akey alst)))
         (b (cdr (assoc 'b alst)))
         (c (cdr (assoc 'foo alst))))
      form)
})

<p>The arguments to the @('assocs') binder should be either single symbols or
pairs of the form @('(var key)'):</p>

<ul>

<li>In the pair form, @('var') is the variable that will be bound to the
associated value of @('key') in the bound object, which should be an alist.
Note that @('key') <i>does not get quoted</i>; it may itself be some
expression.</li>

<li>An argument consisting of the single symbol, @('var'), is equivalent
to the pair @('(var 'var)').</li>

</ul>

<p>Each of the arguments in the @('var') position of the pair form may be a
recursive binder, and @('assocs') may be nested inside other bindings.</p>"

  :body
  (mv-let (pre-bindings name rest)
    (if (and (consp (car forms))
             (not (eq (caar forms) 'quote)))
        (mv `((?tmp-for-assocs ,(car forms)))
            'tmp-for-assocs
            `(check-vars-not-free (tmp-for-assocs)
                            ,rest-expr))
      (mv nil (car forms) rest-expr))
    `(b* (,@pre-bindings
          . ,(assigns-for-assocs args name))
       ,rest)))

(def-b*-binder er
  :short "@(see b*) binder for error triples."
  :long "<p>Usage:</p>
@({
    (b* (((er x) (error-triple-form)))
      (result-form))
})

<p>is equivalent to</p>

@({
     (er-let* ((x (error-triple-form)))
       (result-form))
})

<p>which itself is approximately equivalent to</p>

@({
    (mv-let (erp val state)
            (error-triple-form)
       (if erp
           (mv erp val state)
         (result-form)))
})

<p>The @('er') binder only makes sense as a top-level binding, but its argument
may be a recursive binding.</p>"
  :decls ((declare (xargs :guard (destructure-guard er args forms 1))))
  :body
  `(mv-let (patbind-er-fresh-variable-for-erp
            patbind-er-fresh-variable-for-val
            state)
     ,(car forms)
     (if patbind-er-fresh-variable-for-erp
         (mv patbind-er-fresh-variable-for-erp
             patbind-er-fresh-variable-for-val
             state)
       (patbind ,(car args)
                (patbind-er-fresh-variable-for-val)
                (check-vars-not-free
                 (patbind-er-fresh-variable-for-val
                  patbind-er-fresh-variable-for-erp)
                 ,rest-expr)))))

(def-b*-binder cmp
  :short "@(see b*) binder for context-message pairs."
  :long "<p>Usage:</p>
@({
    (b* (((cmp x) (cmp-returning-form)))
      (result-form))
})

<p>is equivalent to</p>

@({
    (er-let*-cmp ((x (cmp-returning-form)))
      (result-form))
})

<p>which itself is approximately equivalent to</p>

@({
    (mv-let (ctx x)
            (cmp-returning-form)
       (if ctx
           (mv ctx x)
         (result-form)))
})

<p>The @('cmp') binder only makes sense as a top-level binding, but its
argument may be a recursive binding.</p>"

  :decls ((declare (xargs :guard (destructure-guard cmp args forms 1))))

  :body
  `(mv-let (patbind-cmp-fresh-variable-for-ctx
            patbind-cmp-fresh-variable-for-val)
     ,(car forms)
     (if patbind-cmp-fresh-variable-for-ctx
         (mv patbind-cmp-fresh-variable-for-ctx
             patbind-cmp-fresh-variable-for-val)
       (patbind ,(car args)
                (patbind-cmp-fresh-variable-for-val)
                (check-vars-not-free
                 (patbind-cmp-fresh-variable-for-val
                  patbind-cmp-fresh-variable-for-ctx)
                 ,rest-expr)))))


(def-b*-binder state-global
  :short "@(see b*) binder for accessing state globals."
  :long "<p>Usage:</p>
@({
    (b* (((state-global x) (value-form)))
      (result-form))
})

<p>is equivalent to</p>

@({
    (state-global-let* ((x (value-form)))
      (result-form))
})"
  :decls
  ((declare (xargs :guard
                   (and (destructure-guard
                         state-global args forms 1)
                        (or (symbolp (car args))
                            (cw "~%~%**** ERROR ****
Pattern constructor ~x0 needs a single argument which is a symbol, but got ~x1~%~%"
                                'state-global args))))))
  :body
  `(state-global-let*
    ((,(car args) ,(car forms)))
    ,rest-expr))


(def-b*-binder when
  :short "@(see b*) control flow operator."
  :long "<p>The @('when') binder provides a way to exit early from the sequence
of computations represented by a list of @(see b*) binders.</p>

<h5>Typical example:</h5>

@({
    (b* ((lst (some-computation arg1 arg2 ...))
         ((when (atom lst))
          ;; No entries to process, nothing to do, so just return
          ;; nil without building the expensive tbl.
          nil)
         (tbl (build-expensive-table ...)))
      (compute-expensive-result lst tbl ...))
})

<h5>General Form:</h5>

@({
    (b* (((when (condition-form))
          (early-form1)
          ...
          (early-formN))

         ... rest of bindings ...)
      (late-result-form))
})

<p>is equivalent to</p>

@({
    (if (condition-form)
        (progn$ (early-form1)
                ...
                (early-formN))
      (b* (... rest of bindings ...)
        (late-result-form)))
})

<h5>Special Case</h5>

<p>In the special case where no early-forms are provided, the condition itself
is returned.  I.e.,</p>

@({
    (b* (((when (condition-form)))
          ... rest of bindings)
      (late-result-form))
})

<p>is equivalent to</p>

@({
    (or (condition-form)
        (b* (... rest of bindings ...)
          (late-result-form)))
})"

  :decls ((declare (xargs :guard (and (consp args) (eq (cdr args) nil)))))
  :body
  (if forms
      `(if ,(car args)
           (progn$ . , forms)
         ,rest-expr)
    `(or ,(car args) ,rest-expr)))

(def-b*-binder if
  :short "@(see b*) control flow operator."
  :long "<p>The B* binders @('if') and @('when') are exactly equivalent.  See
@(see patbind-when) for documentation.  We generally prefer to use @('when')
instead of @('if').</p>"
  :decls ((declare (xargs :guard (and (consp args) (eq (cdr args) nil)))))
  :body
  `(if ,(car args)
       (progn$ . ,forms)
     ,rest-expr))

(def-b*-binder unless
  :short "@(see b*) control flow operator."
  :long "<p>See @(see patbind-when).  The B* binder @('unless') is identical
except that it negates the condition, so that the early exit is taken when the
condition is false.</p>"
  :decls ((declare (xargs :guard (and (consp args) (eq (cdr args) nil)))))
  :body
  `(if ,(car args)
       ,rest-expr
     (progn$ . ,forms)))

(def-b*-binder run-when
  :short "@(see b*) conditional execution operator."
  :long "<p>Typical example: this always returns @('ans'), but sometimes prints
out warning messages:</p>

@({
     (b* ((ans (some-computation arg1 ... argn))
          ((run-when (< ans 0))
           (cw \"Warning: answer was negative?~%\")
           (cw \"Args were ~x0, ~x1, ...\" arg1 arg2 ...)))
       ans)
})

<p>Usage:</p>

@({
    (b* (((run-when (condition-form))
          (run-form1)
          ...
          (run-formn)))
      (result-form))
})

<p>is equivalent to</p>

@({
    (prog2$ (and (condition-form)
                 (progn$ (run-form1)
                         ...
                         (run-formn)))
            (result-form))
})"
  :decls ((declare (xargs :guard (and (consp args) (eq (cdr args) nil)))))
  :body
  `(prog2$ (and ,(car args)
               (progn$ . , forms))
           ,rest-expr))

(def-b*-binder run-if
  :short "@(see b*) conditional execution operator."
  :long "<p>See @(see patbind-run-when).  The B* binders @('run-if') and
@('run-when') are exactly equivalent.</p>"
  :decls ((declare (xargs :guard (and (consp args) (eq (cdr args) nil)))))
  :body
  `(prog2$ (and ,(car args)
                (progn$ . ,forms))
           ,rest-expr))

(def-b*-binder run-unless
  :short "@(see b*) conditional execution operator."
  :long "<p>See @(see patbind-run-when).  The B* binder @('run-unless') is
exactly like @('run-when'), except that it negates the condition so that the
extra forms are run when the condition is false.</p>"
  :decls ((declare (Xargs :guard (and (consp args) (eq (cdr args) nil)))))
  :body
  `(prog2$ (or ,(car args)
               (progn$ . ,forms))
           ,rest-expr))


(def-b*-binder the
  :short "@(see b*) type declaration operator."
  :long "<p>This b* binder provides a concise syntax for type declarations,
which can sometimes improve the efficiency of Common Lisp code.  See the
documentation for @(see declare) and @(see type-spec) for more information
about type declarations.</p>

<p>Usage example:</p>

@({
    (b* (((the integer x) (form)))
      (result-form))
})

<p>is equivalent to</p>

@({
    (let ((x (form)))
      (declare (type integer x))
      (result-form))
})

<p>The @('the') binder form only makes sense on variables, though those
variables may be prefixed with the @('?') or @('?!') to make them ignorable or
ignored.  It may be nested within other binder forms.</p>"
  :decls
  ((declare (xargs :guard
                   (and (destructure-guard the args forms 2)
                        (or (translate-declaration-to-guard
                             (car args) 'var nil)
                            (cw "~%~%**** ERROR ****
The first argument to pattern constructor ~x0 must be a type-spec, but is ~x1~%~%"
                                'the (car args)))
                        (or (symbolp (cadr args))
                            (cw "~%~%**** ERROR ****
The second argument to pattern constructor ~x0 must be a symbol, but is ~x1~%~%"
                                'the (cadr args)))))))
  :body
  (mv-let (sym ignorep)
    (decode-varname-for-patbind (cadr args))
    (if (eq ignorep 'ignore)
        rest-expr
      `(let ((,sym ,(car forms)))
         ,@(and ignorep `((declare (ignorable ,sym))))
         (declare (type ,(car args) ,sym))
         ,rest-expr))))


;; Find a pair in the alist whose key is a symbol whose name is str.
(defun b*-assoc-symbol-name (str alist)
  (if (atom alist)
      nil
    (if (and (consp (car alist))
             (equal str (symbol-name (caar alist))))
        (car alist)
      (b*-assoc-symbol-name str (cdr alist)))))

(defun b*-decomp-err (arg binder component-alist)
  (er hard? 'b*-decomp-bindings
      "Bad ~s0 binding: ~x2.~%For a ~s0 binding you may use the following ~
       kinds of arguments: keyword/value list form :field binder ..., ~
       name-only where the variable bound is the same as a field name, ~
       or parenthseized (binder :field).  The possible fields are ~v1."
      binder (strip-cars component-alist) arg))

;; Makes b* bindings for a decomposition specified by component-alist.
;; Component-alist binds field names to their accessor functions.
;; Accepts a number of forms of bindings:
(defun b*-decomp-bindings (args binder component-alist var)
  (b* (((when (atom args)) nil)
       ((when (keywordp (car args)))
        (b* ((look (b*-assoc-symbol-name (symbol-name (car args))
                                         component-alist))
             ((unless look)
              (b*-decomp-err (car args) binder component-alist))
             ((unless (consp (cdr args)))
              (b*-decomp-err args binder component-alist)))
          (cons `(,(cadr args) (,(cdr look) ,var))
                (b*-decomp-bindings (cddr args) binder component-alist var))))
       ((when (symbolp (car args)))
        (b* ((look (b*-assoc-symbol-name (symbol-name (car args))
                                         component-alist))
             ((unless look)
              (b*-decomp-err (car args) binder component-alist)))
          (cons `(,(car args) (,(cdr look) ,var))
                (b*-decomp-bindings (cdr args) binder component-alist var))))
       ((unless (and (true-listp (car args))
                     (equal (length (car args)) 2)
                     (symbolp (cadar args))))
        (b*-decomp-err (car args) binder component-alist))
       (look (b*-assoc-symbol-name (symbol-name (cadar args)) component-alist))
       ((unless look)
        (b*-decomp-err (car args) binder component-alist)))
    (cons `(,(caar args) (,(cdr look) ,var))
          (b*-decomp-bindings (cdr args) binder component-alist var))))

(defun b*-decomp-fn (args forms rest-expr binder component-alist)
  (b* (((unless (and (true-listp forms)
                     (= (length forms) 1)))
        (er hard? 'b*-decomp-fn
            "Too many RHS forms in ~x0 binder: ~x1~%" binder forms))
       (rhs (car forms))
       (var (if (symbolp rhs) rhs 'b*-decomp-temp-var))
       (bindings (b*-decomp-bindings args binder component-alist var)))
    `(b* ,(if (symbolp rhs)
              bindings
            (cons `(,var ,rhs) bindings))
       ,rest-expr)))

(defmacro def-b*-decomp (name &rest component-alist)
  `(def-b*-binder ,name
     :body
     (b*-decomp-fn args forms rest-expr ',name ',component-alist)))

(defun patbind-local-stobjs-helper (stobjs retvals form)
  (declare (xargs :mode :program))
  (if (atom stobjs)
      form
    (let* ((stobj (if (consp (car stobjs))
                      (caar stobjs)
                    (car stobjs)))
           (rest-retvals (remove-eq stobj retvals)))
      (patbind-local-stobjs-helper
       (cdr stobjs)
       rest-retvals
       `(with-local-stobj
          ,stobj
          (mv-let ,retvals
            ,form
            ,(if (consp (cdr rest-retvals))
                 `(mv . ,rest-retvals)
               (car rest-retvals)))
          . ,(and (consp (car stobjs))
                  (cdar stobjs)))))))

(defun patbind-local-stobj-arglistp (args)
  (declare (xargs :mode :program))
  (if (atom args)
      (eq args nil)
    (and (let ((x (car args)))
           (or (symbolp x)
               (case-match x
                 ((stobj creator)
                  (and (symbolp stobj)
                       (symbolp creator))))))
         (patbind-local-stobj-arglistp (cdr args)))))

(defun patbind-local-stobjs-fn (args forms rest-expr)
  (declare (xargs :mode :program))
  (b* (((unless (patbind-local-stobj-arglistp args))
        (er hard? 'patbind-local-stobjs-fn
            "In local-stobjs b* binder, arguments must be symbols or
      (stobj creator) pairs"))
       ((unless (and (= (len forms) 1)
                     (symbol-listp (car forms))
                     (eq (caar forms) 'mv)))
        (er hard? 'patbind-local-stobjs-fn
            "In local-stobjs b* binder, bound form must be an MV
              of some symbols, giving the return values"))
       (retvals (cdar forms)))
    (patbind-local-stobjs-helper
     args retvals rest-expr)))

(def-b*-binder local-stobjs
  :short "@(see b*) binder for @(see with-local-stobj) declarations."
  ;; BOZO document me, but gaaah
  :body
  (patbind-local-stobjs-fn args forms rest-expr))

(def-b*-binder fun
  :short "@(see b*) binder to produce @(see flet) forms."
  :long "<p>Usage:</p>

@({
    (b* (((fun (foo a b c)) (body-form)))
      (result-form))
})

<p>is equivalent to</p>

@({
    (flet ((foo (a b c) (body-form)))
      (result-form))
})"
  :decls
  ((declare (xargs :guard
                   (and
                    ;; only arg is a symbol-list (foo a b c)
                    (consp args)
                    (symbol-listp (car args))
                    (consp (car args))
                    (eq (cdr args) nil)
                    ;; body is implicit progn$?
                    (true-listp forms)
                    ))))
  :body
  `(flet ((,(caar args) ,(cdar args) (progn$ . ,forms)))
     ,rest-expr))


(defun access-b*-bindings (recname var pairs)
  (if (atom pairs)
      nil
    (cons
     (if (atom (car pairs))
         (list (car pairs) `(acl2::access ,recname ,var
                                          ,(intern-in-package-of-symbol
                                            (symbol-name (car pairs))
                                            :keyword)))
       (list (caar pairs) `(acl2::access ,recname ,var
                                         ,(intern-in-package-of-symbol
                                           (symbol-name (cadar pairs))
                                           :keyword))))
     (access-b*-bindings recname var (cdr pairs)))))

(def-b*-binder access
  :short "@(see b*) binder for accessing record structure fields introduced
  with ACL2's @('defrec')."
  :body
  `(b* ,(access-b*-bindings (car args) (car forms) (cdr args))
     ,rest-expr))

