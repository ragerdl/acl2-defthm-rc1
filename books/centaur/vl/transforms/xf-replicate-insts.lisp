; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
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
; Original author: Jared Davis <jared@centtech.com>

(in-package "VL")
(include-book "xf-partition-lvalue")
(include-book "../mlib/namefactory")
(include-book "../mlib/hierarchy")
;(include-book "../wf-ranges-simple-p")
(local (include-book "../util/arithmetic"))


(defxdoc replicate
  :parents (transforms)
  :short "Eliminate arrays of gate and module instances."

  :long "<p>We now introduce a transformation which eliminates \"ranges\" from
gate and module instances.  The basic idea is to transform things like this:</p>

<code>
   type instname [N:0] (arg1, arg2, ..., argM) ;
</code>

<p>Into things like this:</p>

<code>
   type instname_0 (arg1-0, arg2-0, ..., argM-0);
   type instname_1 (arg1-1, arg2-1, ..., argM-1);
   ...
   type instname_N (arg1-N, arg2-N, ..., argM-N);
</code>

<p>Here, <tt>type</tt> might be a gate type (e.g., <tt>not</tt>, <tt>xor</tt>,
etc.) or a module name, <tt>instname</tt> is the name of this instance array,
and the arguments are expressions which represent the inputs and outputs.</p>

<p><b>Ordering Notes</b>.  We require that (1) @(see argresolve) has been
applied so there are only plain argument lists to deal with, that (2) all
expressions have been sized so we can determine the sizes of arguments and
ports, and (3) that @(see drop-blankports) has been run so that there are no
blank ports.  We also expect that all output ports are connected to legitimate
lvalues (identifiers, selects, and concatenates, but nothing else).  We cause
fatal warnings if these conditions are violated.  However, this transformation
should be run before @(see blankargs), so there may be blank arguments (but not
blank ports.)</p>

<p>The semantics of instance arrays are covered in Section 7.1.5 and 7.1.6, and
per Section 12.1.2 they hold for both gate instances and module instances.</p>

<p>One minor issue to address is that the names of all instances throughout a
module need to be unique, and so we need to take care that the instance names
we are generating (i.e., instname_0, etc.) do not clash with other names in the
module; we discuss this further in @(see vl-replicate-instnames).</p>

<p>But the most complicated thing about splitting instances is how to come up
with the new arguments for each new instance we are generating, which we now
address.</p>

<h3>Argument Partitioning</h3>

<p>Let us consider a particular, non-blank argument, <tt>ArgI</tt>, whose width
is <tt>ArgI-W</tt>.  Suppose this argument is connected to a non-blank port
with width <tt>P-W</tt>.</p>

<p>To clarify, if we are talking about module instances then this is quite
straightforward: the module has a list of ports, and we can see how wide these
ports are supposed to be by looking at the widths of their port expressions;
see @(see vl-port-p).  The argument <tt>ArgI</tt> corresponds to some
particular port, and so the width of that port is what <tt>P-W</tt> is going to
be.  If we are talking about gates, then P-W is always 1.</p>

<p>According to the semantics laid forth in 7.1.6, there are only two valid
cases.</p>

<p><b>Case 1.</b> <tt>ArgI-W = P-W.</tt> In this case, the argument is simply
to be replicated, verbatim, across all of the new instances.</p>

<p><b>Case 2.</b> <tt>ArgI-W = P-W * K</tt>, where <tt>K</tt> is the number of
instances specified by this array.  That is, if our instance array declaration
is:</p>

<code>
    type instname [N:0] (arg1, arg2, ...);
</code>

<p>then <tt>K</tt> is <tt>N+1</tt>.  In this case, we are going to slice up
<tt>ArgI</tt> into <tt>K</tt> segments of <tt>P-W</tt> bits each, and send them
off to the instances.  For example, in the code:</p>

<code>
    wire w[3:0];
    not g [3:0] (w, 4'b0011);
</code>

<p>The <tt>ArgI-W</tt> of both <tt>w</tt> and <tt>4'b0011</tt> is four, while
the <tt>P-W</tt> is 1.  In this case, we create four one-bit slices of
<tt>w</tt>, and four one-bit slices of <tt>4'b0011</tt>, and connect them with
four separate not-gates.</p>

<p>When we are dealing with gates, <tt>P-W</tt> is always 1.  But when we talk
about modules, <tt>P-W</tt> might be larger.  For example, consider the
module:</p>

<code>
   module two_bit_and (o, a, b) ;
      output [1:0] o;
      input [1:0] a;
      input [1:0] b;
      assign o = a &amp; b;
   endmodule
</code>

<p>And here we have an array of these two_bit_and modules:</p>

<code>
   wire [7:0] j;
   two_bit_and myarray [3:0] (j, 8'b 11_00_10_01, 2'b 01);
</code>

<p>This array is equivalent to:</p>

<code>
   two_bit_and myarray_0 (j[7:6], 2'b 11, 2'b 01) ;
   two_bit_and myarray_1 (j[5:4], 2'b 00, 2'b 01) ;
   two_bit_and myarray_2 (j[3:2], 2'b 10, 2'b 01) ;
   two_bit_and myarray_3 (j[1:0], 2'b 01, 2'b 01) ;
</code>

<p>And so the value of <tt>j</tt> will be <tt>8'b 0100_0001</tt>.</p>

<p>That is, since all of the ports of two_bit_and are 2 bits, and we are
creating four instances, each of the array arguments can only be 2 or 8 bits
long.  Any 8-bit arguments are split into 2-bit slices, and any 2-bit arguments
are replicated.</p>")

(deflist vl-plainarglistlist-p (x)
  (vl-plainarglist-p x)
  :elementp-of-nil t)

(defthm vl-plainarglist-p-of-strip-cars
  (implies (and (vl-plainarglistlist-p x)
                (all-have-len x n)
                (not (zp n)))
           (vl-plainarglist-p (strip-cars x)))
  :hints(("Goal" :induct (len x))))

(defthm vl-plainarglistlist-p-of-strip-cdrs
  (implies (vl-plainarglistlist-p x)
           (vl-plainarglistlist-p (strip-cdrs x)))
  :hints(("Goal" :induct (len x))))


(deflist vl-argumentlist-p (x)
  (vl-arguments-p x)
  :elementp-of-nil nil)



(defsection vl-plainarglists-to-arguments
  :parents (mlib)
  :short "Convert each plainarglist in a @(see vl-plainarglistlist-p) into an
@(see vl-argument-p)."

  (defund vl-plainarglists-to-arguments (x)
    (declare (xargs :guard (vl-plainarglistlist-p x)))
    (if (consp x)
        (cons (vl-arguments nil (car x))
              (vl-plainarglists-to-arguments (cdr x)))
      nil))

  (local (in-theory (enable vl-plainarglists-to-arguments)))

  (defthm vl-argumentlist-p-of-vl-plainarglists-to-arguments
    (implies (force (vl-plainarglistlist-p x))
             (vl-argumentlist-p (vl-plainarglists-to-arguments x))))

  (defthm len-of-vl-plainarglists-to-arguments
    (equal (len (vl-plainarglists-to-arguments x))
           (len x))))



(defsection vl-replicated-instnames
  :parents (replicate)
  :short "Safely generate the instance names for @(see replicate)d instances."

  :long "<p><b>Signature:</b> @(call vl-replicated-instnames) returns <tt>(MV
WARNINGS' NAMES NF')</tt>.</p>

<p>We are given <tt>instname</tt>, a string that should be the name of some
gate or module instance array, e.g., <tt>foo</tt> in:</p>

<code>
   type foo [N:0] (arg1, arg2, ..., argM);
</code>

<p>and <tt>instrange</tt>, which should be the associated range, e.g.,
<tt>[N:0]</tt>.  We are also given <tt>nf</tt>, a @(see vl-namefactory-p) for
generating new names, and a @(see warnings) accumulator which may be extended
with a non-fatal warning if our preferred names are unavailable.  The
<tt>inst</tt> is semantically irrelevant and is only as a context for
warnings.</p>

<p>We produce <tt>names</tt>, a list of <tt>N+1</tt> names that are to be used
as the instance names for the split up arguments.  We prefer to use names of
the form <tt>instname_index</tt>, e.g., we would prefer to split the above
instance array into:</p>

<code>
   type foo_0 (arg1-0, arg2-0, ..., argM-0);
   type foo_1 (arg1-1, arg2-1, ..., argM-1);
   ...
   type foo_N (arg1-N, arg2-N, ..., argM-N);
</code>

<p>The names we return are in <tt>foo_N, ..., foo_0</tt> order, to agree with
@(see vl-partition-lvalue).</p>

<p>We really want the split up names to correspond to the original name, since
otherwise it can be very hard to understand the relationship of the transformed
module's state to the original module.</p>"

  (defund vl-preferred-replicate-names (low high instname)
    "The names we'd like to use... typically this is something like (foo_0 foo_1
   ... foo_N), but we can also handle ranges like [5:3] by producing (foo_3
   foo_4 foo_5)."
    (declare (xargs :guard (and (natp low)
                                (natp high)
                                (<= low high)
                                (stringp instname))
                    :measure (nfix (- (nfix high) (nfix low)))))
    (let ((low  (mbe :logic (nfix low) :exec low))
          (high (mbe :logic (nfix high) :exec high))
          (name (str::cat instname "_" (str::natstr low))))
      (if (mbe :logic (zp (- high low))
               :exec (= low high))
          (list name)
        (cons name (vl-preferred-replicate-names (+ 1 low) high instname)))))

  (defthm string-listp-of-vl-preferred-replicate-names
    (string-listp (vl-preferred-replicate-names low high instname))
    :hints(("Goal" :in-theory (enable vl-preferred-replicate-names))))

  (defthm len-of-vl-preferred-replicate-names
    (equal (len (vl-preferred-replicate-names low high instname))
           (+ 1 (nfix (- (nfix high) (nfix low)))))
    :hints(("Goal" :in-theory (enable vl-preferred-replicate-names))))


  (defund vl-bad-replicate-names (n basename nf)
    "Returns (MV NAMES NF').  This is our fallback function which we only use if
  we can't use our preferred names due to name conflicts."
    (declare (xargs :guard (and (natp n)
                                (stringp basename)
                                (vl-namefactory-p nf))))
    (b* (((when (zp n))
          (mv nil nf))
         ((mv name nf)
          (vl-namefactory-indexed-name basename nf))
         ((mv others nf)
          (vl-bad-replicate-names (- n 1) basename nf)))
        (mv (cons name others) nf)))

  (defthm vl-bad-replicate-names-props
    (implies (and (force (stringp basename))
                  (force (vl-namefactory-p nf)))
             (and (string-listp (mv-nth 0 (vl-bad-replicate-names n basename nf)))
                  (vl-namefactory-p (mv-nth 1 (vl-bad-replicate-names n basename nf)))))
    :hints(("Goal" :in-theory (enable vl-bad-replicate-names))))

  (defthm len-of-vl-bad-replicate-names
    (equal (len (mv-nth 0 (vl-bad-replicate-names n basename nf)))
           (nfix n))
    :hints(("Goal" :in-theory (enable vl-bad-replicate-names))))


  (local (in-theory (enable vl-range-resolved-p)))

  (defund vl-replicated-instnames (instname instrange nf inst warnings)
    "Returns (MV WARNINGS NAMES NF')"
    (declare (xargs :guard (and (vl-maybe-string-p instname)
                                (vl-range-p instrange)
                                (vl-range-resolved-p instrange)
                                (vl-namefactory-p nf)
                                (or (vl-modinst-p inst)
                                    (vl-gateinst-p inst))
                                (vl-warninglist-p warnings))))
    (b* ((high (vl-resolved->val (vl-range->left instrange)))
         (low  (vl-resolved->val (vl-range->right instrange)))
         (instname (or instname "unnamed"))
         (want (vl-preferred-replicate-names low high instname))
         ((mv fresh nf)
          (vl-namefactory-plain-names want nf))
         ((when (equal want fresh))
          ;; Great -- we can use exactly what we want to use.
          (mv warnings (reverse fresh) nf))
         ;; Use bad names.
         ((mv fresh nf)
          (vl-bad-replicate-names (+ 1 (- high low))
                                  (str::cat "vl_badname_" instname)
                                  nf))
         (warnings
          (cons (make-vl-warning
                 :type :vl-warn-replicate-name
                 :msg "~a0: preferred names for instance array ~s1 are not ~
                     available, so using lousy vl_badname_* naming scheme ~
                     instead.  This conflict is caused by ~&2."
                 :args (list inst instname
                             (difference (mergesort want) (mergesort fresh)))
                 :fatalp nil
                 :fn 'vl-replicated-instnames)
                warnings)))
        (mv warnings (reverse fresh) nf)))

  (local (in-theory (enable vl-replicated-instnames)))

  (defthm vl-warninglist-p-of-vl-replicated-instnames
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 0 (vl-replicated-instnames instname instrange nf inst warnings)))))

  (defthm string-listp-of-vl-replicated-instnames
    (implies (and (force (vl-maybe-string-p instname))
                  (force (vl-namefactory-p nf)))
             (string-listp
              (mv-nth 1 (vl-replicated-instnames instname instrange nf inst warnings)))))

  (defthm len-of-vl-replicated-instnames
    (implies (and (force (vl-range-resolved-p instrange))
                  (force (vl-namefactory-p nf)))
             (equal
              (len (mv-nth 1 (vl-replicated-instnames instname instrange nf inst warnings)))
              (vl-range-size instrange)))
    :hints(("Goal" :in-theory (e/d (vl-range-size)))))

  (defthm vl-namefactory-p-of-vl-replicated-instnames
    (implies (and (force (vl-maybe-string-p instname))
                  (force (vl-range-p instrange))
                  (force (vl-range-resolved-p instrange))
                  (force (vl-namefactory-p nf)))
             (vl-namefactory-p
              (mv-nth 2 (vl-replicated-instnames instname instrange nf inst warnings))))))




(defsection vl-partition-plainarg-aux
  :parents (vl-partition-plainarg)
  :short "Convert expressions into plainargs."
  :long "<p>Suppose we have split an argument into a number of slices, which
are expressions <tt>E1</tt>, <tt>E2</tt>, ..., <tt>Ek</tt>.  This function just
turns those expressions into plainargs, by attaching the appropriate direction
and replicating the attributes of the original argument.</p>"

  (defund vl-partition-plainarg-aux (exprs dir atts)
    (declare (xargs :guard (and (vl-exprlist-p exprs)
                                (vl-maybe-direction-p dir)
                                (vl-atts-p atts))))
    (if (consp exprs)
        (cons (make-vl-plainarg :expr (car exprs) :dir dir :atts atts)
              (vl-partition-plainarg-aux (cdr exprs) dir atts))
      nil))

  (local (in-theory (enable vl-partition-plainarg-aux)))

  (defthm vl-plainarglist-p-of-vl-partition-plainarg-aux
    (implies (and (force (vl-exprlist-p exprs))
                  (force (vl-maybe-direction-p dir))
                  (force (vl-atts-p atts)))
             (vl-plainarglist-p (vl-partition-plainarg-aux exprs dir atts))))

  (defthm len-of-vl-partition-plainarg-aux
    (equal (len (vl-partition-plainarg-aux exprs dir atts))
           (len exprs))))




(defsection vl-partition-plainarg
  :parents (replicate)
  :short "Partition a plain argument into slices."

  :long "<p><b>Signature:</b> @(call vl-partition-plainarg) returns <tt>(mv
warnings plainargs)</tt>.</p>

<p>As inputs,</p>

<ul>

  <li><tt>arg</tt> is a plainarg which we may need to replicate,</li>

  <li><tt>port-width</tt> is the width of the port this argument is
    connected to.</li>

  <li><tt>insts</tt> is the number of instances in this array,</li>

  <li><tt>mod</tt> is the mod we are in (so we can look up wire ranges),
  and</li>

  <li><tt>warnings</tt> is an accumulator for warnings.</li>

</ul>

<p>Our goal is to create a list of the <tt>insts</tt>-many plainargs which this
port is to be partitioned into.</p>"

  (defund vl-partition-plainarg (arg port-width insts mod warnings)
    "Returns (MV WARNINGS PLAINARGS)"
    (declare (xargs :guard (and (vl-plainarg-p arg)
                                (posp port-width)
                                (posp insts)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))


    (b* ((expr (vl-plainarg->expr arg))
         ((unless expr)
          ;; Special case for blanks: If we have a blank in an array of
          ;; instances, we just want to send blank to each member of the
          ;; instance.
          (mv warnings (repeat arg insts)))

         (expr-width (vl-expr->finalwidth expr))
         ((unless (posp expr-width))
          ;; Quick sanity check.
          (mv (cons (make-vl-warning
                     :type :vl-bad-argument
                     :msg "Expected widths to be computed, but found ~
                           expression ~a0 without any width assigned."
                     :args (list expr)
                     :fatalp t
                     :fn 'vl-partition-plainarg)
                    warnings)
              ;; Senseless value for nice theorem.
              (repeat arg insts)))

         ((when (= expr-width port-width))
          ;; The port is exactly as wide as the argument being given to it.
          ;; We are to replicate the argument, verbatim, across all of the
          ;; instances we are creating.
          (mv warnings (repeat arg insts)))

         ;; Otherwise, the port is not the same width as the argument.  In this
         ;; case, the argument's width should be a multiple of the port's
         ;; width.  Lets try to partition the argument into port-width-bit
         ;; segments.
         ((mv successp exprs)
          (vl-partition-lvalue expr port-width mod))

         ((unless successp)
          ;; We failed outright.  The expr's width is not a multiple of the
          ;; port's width.
          (mv (cons (make-vl-warning
                     :type :vl-bad-argument
                     :msg "Cannot partition ~x0-bit argument into ~x1-bit ~
                           slices: ~a1."
                     :args (list expr-width port-width expr)
                     :fatalp t
                     :fn 'vl-partition-plainarg)
                    warnings)
              ;; Senseless value for nice theorem
              (repeat arg insts)))

         ((unless (= (len exprs) insts))
          ;; Partitioning was successful, but we got the wrong number of
          ;; instances!
          ;; BOZO we can probably prove this away now?
          (mv (cons (make-vl-warning
                     :type :vl-bad-argument
                     :msg "Wanted ~x0 ~x1-bit partitions of the ~x2-bit ~
                           argument, ~a3, but ~x4 were produced."
                     :args (list insts port-width expr-width expr (len exprs))
                     :fatalp t
                     :fn 'vl-partition-plainarg)
                    warnings)
              ;; Senseless value for nice theorem
              (repeat arg insts)))

         ;; Otherwise, the argument has been partitioned into inst-many new
         ;; arguments, each of which has port-width bits.  That's exactly what
         ;; we want.  Now turn those all into ports, instead of expressions.
         (plainargs (vl-partition-plainarg-aux exprs
                                               (vl-plainarg->dir arg)
                                               (vl-plainarg->atts arg))))

        (mv warnings plainargs)))

  (local (in-theory (enable vl-partition-plainarg)))

  (defthm vl-warninglist-p-of-vl-partition-plainarg
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 0 (vl-partition-plainarg arg port-width insts mod warnings)))))

  (defthm vl-plainarglist-p-of-vl-partition-plainarg
    (implies (and (force (vl-plainarg-p arg))
                  (force (posp port-width))
                  (force (vl-module-p mod)))
             (vl-plainarglist-p
              (mv-nth 1 (vl-partition-plainarg arg port-width insts mod warnings)))))

  (defthm len-of-vl-partition-plainarg
    (equal (len (mv-nth 1 (vl-partition-plainarg arg port-width insts mod warnings)))
           (nfix insts))))




(defsection vl-partition-plainarglist
  :parents (replicate)
  :short "Extend @(see vl-partition-plainarg) across a list of arguments."

  :long "<p><b>Signature:</b> @(call vl-partition-plainarglist) returns <tt>(mv
warnings result)</tt>, where <tt>result</tt> is a @(see vl-plainarglistlist-p),
i.e., a list of @(see vl-plainarglist-p)'s.</p>

<p>The inputs are as follows:</p>

<ul>

<li><tt>args</tt> is a plainarglist which represents the actuals of some gate
or module instance,</li>

<li><tt>port-widths</tt> are a list of positive numbers, which represent the
sizes of these arguments, and which has the same length as <tt>args</tt>,</li>

<li><tt>insts</tt> is the number of instances we are trying to generate, i.e.,
the size of the range of this instance array, and</li>

<li><tt>mod</tt> is the module we are in (so we can look up wire ranges),</li>

<li><tt>warnings</tt> is an accumulator for warnings.</li>

</ul>

<p>Supposing that <tt>args</tt> has length <i>N</i>, the <tt>result</tt> we
return is a list of <i>N</i> plainarglists (one for each argument), and each of
these lists has <tt>insts</tt>-many plainargs.  That is, each element of the
<tt>result</tt> is the partitioning of the corresponding argument.</p>"

  (defund vl-partition-plainarglist (args port-widths insts mod warnings)
    "Returns (MV WARNINGS PLAINARGLISTS)"
    (declare (xargs :guard (and (vl-plainarglist-p args)
                                (pos-listp port-widths)
                                (same-lengthp args port-widths)
                                (posp insts)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))
    (if (atom args)
        (mv warnings nil)
      (b* (((mv warnings car-result)
            (vl-partition-plainarg (car args) (car port-widths) insts mod warnings))
           ((mv warnings cdr-result)
            (vl-partition-plainarglist (cdr args) (cdr port-widths) insts mod warnings)))
          (mv warnings (cons car-result cdr-result)))))

  (defmvtypes vl-partition-plainarglist (nil true-listp))

  (local (in-theory (enable vl-partition-plainarglist)))

  (defthm vl-warninglist-p-of-vl-partition-plainarglist
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 0 (vl-partition-plainarglist args port-widths insts mod warnings)))))

  (defthm vl-plainarglistlist-p-of-vl-partition-plainarglist
    (implies (and (force (vl-plainarglist-p args))
                  (force (same-lengthp args port-widths))
                  (force (pos-listp port-widths))
                  (force (vl-module-p mod)))
             (vl-plainarglistlist-p
              (mv-nth 1 (vl-partition-plainarglist args port-widths insts mod warnings)))))

  (defthm all-have-len-of-vl-partition-plainarglist
    (implies (force (natp insts))
             (all-have-len
              (mv-nth 1 (vl-partition-plainarglist args port-widths insts mod warnings))
              insts))))




(defsection vl-reorient-partitioned-args
  :parents (replicate)
  :short "Group arguments for instances after @(see vl-partition-plainarglist)."

  :long "<p><b>Signature:</b> @(call vl-reorient-partitioned-args) returns a
@(see vl-plainarglistlist-p).</p>

<p>We are given <tt>lists</tt>, which should be a @(see vl-plainarglistlist-p)
formed by calling @(see vl-partition-plainarglist), and <tt>n</tt>, the number
of instances we are trying to generate.  Note that every list in <tt>lists</tt>
has length <tt>n</tt>.</p>

<p>At this point, the args are bundled up in a bad order.  That is, to create
the new instances, we want to have lists of the form</p>

<code>
   (arg1-slice1 arg2-slice1 arg3-slice1 ...) for the first instance,
   (arg1-slice2 arg2-slice2 arg3-slice2 ...) for the second instance,
   etc.
</code>

<p>But instead, what @(see vl-partition-plainarglist) does is create lists
of the slices, e.g., </p>

<code>
   (arg1-slice1 arg1-slice2 arg1-slice3 ...)
   (arg2-slice1 arg2-slice2 arg2-slice3 ...)
   etc.
</code>

<p>So our goal is simply to simply transpose this matrix and aggregate the
data by slice, rather than by argument.</p>"

  (defund vl-reorient-partitioned-args (lists n)
    (declare (xargs :guard (and (all-have-len lists n)
                                (true-listp lists)
                                (natp n))))
    (if (zp n)
        nil
      (cons (strip-cars lists)
            (vl-reorient-partitioned-args (strip-cdrs lists) (- n 1)))))

  (local (in-theory (enable vl-reorient-partitioned-args)))

  (defthm vl-plainarglistlist-p-of-vl-reorient-partitioned-args
    (implies (and (vl-plainarglistlist-p lists)
                  (all-have-len lists n))
             (vl-plainarglistlist-p (vl-reorient-partitioned-args lists n))))

  (defthm all-have-len-of-vl-reorient-partitioned-args
    (all-have-len (vl-reorient-partitioned-args lists n)
                  (len lists)))

  (defthm len-of-vl-reorient-partitioned-args
    (equal (len (vl-reorient-partitioned-args lists n))
           (nfix n))))


#||

;; Here's a quick little example:

(defconst *matrix*
  '((a1 a2 a3)
    (b1 b2 b3)
    (c1 c2 c3)
    (d1 d2 d3)))

(vl-reorient-partitioned-args *matrix* 3)

||#



(defsection vl-assemble-gateinsts
  :parents (replicate)
  :short "Build @(see vl-gateinst-p)'s from the sliced-up arguments."

  :long "<p><b>Signature:</b> @(call vl-assemble-gateinsts) returns a @(see
vl-gateinstlist-p).</p>

<p><tt>names</tt> are the names to give the instances and <tt>args</tt> are the
reoriented, partitioned arguments (see @(see vl-partition-plainarglist) and
@(see vl-reorient-partitioned-args); the other arguments are replicated from
the gate instance.  We create the new gates.</p>"

  (defund vl-assemble-gateinsts (names args type strength delay atts loc)
    (declare (xargs :guard (and (string-listp names)
                                (vl-plainarglistlist-p args)
                                (same-lengthp names args)
                                (vl-gatetype-p type)
                                (vl-maybe-gatestrength-p strength)
                                (vl-maybe-gatedelay-p delay)
                                (vl-atts-p atts)
                                (vl-location-p loc))))
    (if (atom args)
        nil
      (cons (make-vl-gateinst :type type
                              :name (car names)
                              :range nil
                              :strength strength
                              :delay delay
                              :args (car args)
                              :atts atts
                              :loc loc)
            (vl-assemble-gateinsts (cdr names) (cdr args) type strength delay atts loc))))

  (local (in-theory (enable vl-assemble-gateinsts)))

  (defthm vl-gateinstlist-p-of-vl-assemble-gateinsts
    (implies (and (force (string-listp names))
                  (force (vl-plainarglistlist-p args))
                  (force (same-lengthp names args))
                  (force (vl-gatetype-p type))
                  (force (vl-maybe-gatestrength-p strength))
                  (force (vl-maybe-gatedelay-p delay))
                  (force (vl-atts-p atts))
                  (force (vl-location-p loc)))
             (vl-gateinstlist-p
              (vl-assemble-gateinsts names args type strength delay atts loc)))))




(defsection vl-replicate-gateinst
  :parents (replicate)
  :short "Convert a gate into a list of simpler gates, if necessary."

  :long "<p><b>Signature:</b> @(call vl-replicate-gateinst) returns <tt>(mv
warnings new-gateinsts new-nf)</tt>.</p>

<p><tt>x</tt> is some gate, <tt>warnings</tt> is an accumulator for warnings,
<tt>mod</tt> is the module we are working in, and <tt>nf</tt> is a @(see
vl-namefactory-p) for generating names.  If <tt>x</tt> has a range, i.e., it is
an array of gate instances, then we try to split it into a list of
<tt>nil</tt>-ranged, simple gates.  The <tt>new-gateinsts</tt> should replace
<tt>x</tt> in the module.</p>"

  (defund vl-replicate-gateinst (x nf mod warnings)
    "Returns (MV WARNINGS' NEW-GATEINSTS NF')"
    (declare (xargs :guard (and (vl-gateinst-p x)
                                (vl-namefactory-p nf)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))
    (b* ((range    (vl-gateinst->range x))
         (type     (vl-gateinst->type x))
         (name     (vl-gateinst->name x))
         (strength (vl-gateinst->strength x))
         (delay    (vl-gateinst->delay x))
         (args     (vl-gateinst->args x))
         (loc      (vl-gateinst->loc x))
         (atts     (vl-gateinst->atts x))
         ((unless range)
          ;; There is no range, so this is not an array of gates; we don't
          ;; need to do anything.
          (mv warnings (list x) nf))

         ((unless (vl-range-resolved-p range))
          (b* ((w (make-vl-warning
                   :type :vl-bad-gate
                   :msg "~a0: expected range of instance array to be ~
                           resolved, but found ~a1."
                   :args (list x range)
                   :fatalp t
                   :fn 'vl-replicate-gateinst)))
            (mv (cons w warnings) (list x) nf)))

         ;; We add an annotation saying that these instances are from a gate
         ;; array.
         (atts        (cons (list "VL_FROM_GATE_ARRAY") atts))

         ;; We previously checked that size was positive, but via the theorem
         ;; posp-of-vl-range-size this check was not necessary; size is always
         ;; positive.
         (size        (vl-range-size range))

         ;; Claim: The port widths for gates are always 1.  BOZO is there any
         ;; evidence to support this claim, from the Verilog spec?
         (port-widths (repeat 1 (len args)))

         ;; Partition the args into their slices, then transpose the slices to
         ;; form the new argument lists for the instances we are going to
         ;; generate.
         ((mv warnings slices) (vl-partition-plainarglist args port-widths size mod warnings))
         (transpose            (vl-reorient-partitioned-args slices size))

         ;; Come up with names for these instances.
         ((mv warnings names nf)
          (vl-replicated-instnames name range nf x warnings))

         ;; Finally, assemble the gate instances.
         (new-gates (vl-assemble-gateinsts names transpose type strength delay atts loc)))

        ;; And that's it!
        (mv warnings new-gates nf)))

  (defmvtypes vl-replicate-gateinst (nil true-listp nil))

  (local (in-theory (enable vl-replicate-gateinst)))

  (defthm vl-warninglist-p-of-vl-replicate-gateinst
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p (mv-nth 0 (vl-replicate-gateinst x nf mod warnings)))))

  (defthm vl-gateinstlist-p-of-vl-replicate-gateinst
    (implies (and (force (vl-gateinst-p x))
                  (force (vl-namefactory-p nf))
                  (force (vl-module-p mod)))
             (vl-gateinstlist-p (mv-nth 1 (vl-replicate-gateinst x nf mod warnings)))))

  (defthm vl-namefactory-p-of-vl-replicate-gateinst
    (implies (and (force (vl-gateinst-p x))
                  (force (vl-namefactory-p nf)))
             (vl-namefactory-p (mv-nth 2 (vl-replicate-gateinst x nf mod warnings))))))




(defsection vl-replicate-gateinstlist
  :parents (replicate)
  :short "Extend @(see vl-replicate-gateinst) across a @(see
vl-gateinstlist-p)."

  :long "<p><b>Signature</b>: @(call vl-replicate-gateinstlist) returns <tt>(mv
warnings new-gateinsts new-nf)</tt>.</p>

<p><tt>new-gateinsts</tt> is a list of new gates, which should replace
<tt>x</tt> in the module.</p>"

  (defund vl-replicate-gateinstlist (x nf mod warnings)
    "Returns (MV WARNINGS NEW-GATEINSTS NEW-NF)"
    (declare (xargs :guard (and (vl-gateinstlist-p x)
                                (vl-namefactory-p nf)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))
    (b* (((when (atom x))
          (mv warnings nil nf))
         ((mv warnings car-prime nf)
          (vl-replicate-gateinst (car x) nf mod warnings))
         ((mv warnings cdr-prime nf)
          (vl-replicate-gateinstlist (cdr x) nf mod warnings))
         (new-gateinsts (append car-prime cdr-prime)))
        (mv warnings new-gateinsts nf)))

  (defmvtypes vl-replicate-gateinstlist (nil true-listp nil))

  (local (in-theory (enable vl-replicate-gateinstlist)))

  (defthm vl-warninglist-p-of-vl-replicate-gateinstlist
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p (mv-nth 0 (vl-replicate-gateinstlist x nf mod warnings)))))

  (defthm vl-gateinstlist-p-of-vl-replicate-gateinstlist
    (implies (and (force (vl-gateinstlist-p x))
                  (force (vl-module-p mod))
                  (force (vl-namefactory-p nf)))
             (vl-gateinstlist-p (mv-nth 1 (vl-replicate-gateinstlist x nf mod warnings)))))

  (defthm vl-namefactory-p-of-vl-replicate-gateinstlist
    (implies (and (force (vl-gateinstlist-p x))
                  (force (vl-namefactory-p nf)))
             (vl-namefactory-p (mv-nth 2 (vl-replicate-gateinstlist x nf mod warnings))))))




(defsection vl-replicate-arguments
  :parents (replicate)
  :short "Partition arguments for a module instance"

  :long "<p><b>Signature:</b> @(call vl-replicate-arguments) returns <tt>(mv
warnings arg-lists)</tt>.</p>

<ul>

<li><tt>args</tt> is a single @(see vl-arguments-p) object, which should be the
<tt>portargs</tt> from a @(see vl-modinst-p).  We expect that the arguments
have already been resolved, so that <tt>args</tt> contains a plainarglist
rather than named arguments.</li>

<li><tt>port-widths</tt> are the widths from the corresponding ports, and we
check to ensure that there are as many <tt>port-widths</tt> as there are
arguments in <tt>args</tt>.</li>

<li><tt>insts</tt> is the number of instances that we are splitting these
arguments into.</li>

<li><tt>mod</tt> is the module we are working in.</li>

<li><tt>warnings</tt> is an accumulator for warnings.</li>

</ul>

<p>The <tt>arg-lists</tt> we produce is a @(see vl-argumentslist-p) of length
<tt>insts</tt>, and contains the new arguments to use in the split up
module instances.</p>"

  (defund vl-replicate-arguments (args port-widths insts mod warnings)
    "Returns (MV WARNINGS ARG-LISTS)"
    (declare (xargs :guard (and (vl-arguments-p args)
                                (pos-listp port-widths)
                                (posp insts)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))
    (let ((namedp  (vl-arguments->namedp args))
          (actuals (vl-arguments->args args)))
      (cond (namedp
             ;; Not a very good error message.  The value we return is
             ;; senseless, but gives us a nice length theorem.
             (mv (cons (make-vl-warning
                        :type :vl-bad-arguments
                        :msg "Expected only plain argument lists, but found ~
                              named args instead."
                        :fatalp t
                        :fn 'vl-replicate-arguments)
                       warnings)
                 (repeat args insts)))

            ((not (same-lengthp actuals port-widths))
             ;; Not a very good error message.  The value we return is
             ;; senseless, but gives us a nice length theorem.
             (mv (cons (make-vl-warning
                        :type :vl-bad-arguments
                        :msg "Expected ~x0 arguments but found ~x1."
                        :args (list (len port-widths) (len actuals))
                        :fatalp t
                        :fn 'vl-replicate-arguments)
                       warnings)
                 ;; This is senseless, but gives us a nice length theorem.
                 (repeat args insts)))

            (t
             (b* ( ;; Slice up the arguments, as before
                  ((mv warnings slices)
                   (vl-partition-plainarglist actuals port-widths insts mod warnings))
                  ;; Transpose the matrix into slice-order
                  (transpose
                   (vl-reorient-partitioned-args slices insts))
                  ;; Turn the plainarglists into vl-arguments-p structures
                  (arg-lists
                   (vl-plainarglists-to-arguments transpose)))
                 (mv warnings arg-lists))))))

  (local (in-theory (enable vl-replicate-arguments)))

  (defthm vl-warninglist-p-of-vl-replicate-arguments
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 0 (vl-replicate-arguments args port-widths insts mod warnings)))))

  (defthm vl-argumentlist-p-of-vl-replicate-arguments
    (implies (and (force (vl-arguments-p args))
                  (force (pos-listp port-widths))
                  (force (vl-module-p mod))
                  (force (posp insts)))
             (vl-argumentlist-p
              (mv-nth 1 (vl-replicate-arguments args port-widths insts mod warnings)))))

  (defthm len-of-vl-replicate-arguments
    (equal (len (mv-nth 1 (vl-replicate-arguments args port-widths insts mod warnings)))
           (nfix insts))))




(defsection vl-module-port-widths
  :parents (replicate)
  :short "Determine the widths of a module's ports."

  :long "<p><b>Signature:</b> @(call vl-module-port-widths) returns a <tt>(mv
successp warnings widths)</tt>, where <tt>widths</tt> is a list of positive
numbers.</p>

<ul>

<li><tt>ports</tt> are the module's ports.</li>

<li><tt>inst</tt> is the module instance that we are trying to replicate, and
is only used to generate more useful error messages.</li>

<li><tt>warnings</tt> is an ordinary @(see warnings) accumulator.</li>

</ul>

<p>We fail and cause fatal errors if any port is blank or does not have a
positive width.</p>"

  (defund vl-module-port-widths (ports inst warnings)
    (declare (xargs :guard (and (vl-portlist-p ports)
                                (vl-modinst-p inst)
                                (vl-warninglist-p warnings))))
    (b* (((when (atom ports))
          (mv t warnings nil))

         (expr1  (vl-port->expr (car ports)))
         (width1 (and expr1 (vl-expr->finalwidth expr1)))
         ((unless (posp width1))
          (mv nil
              (cons (make-vl-warning
                     :type :vl-replicate-fail
                     :msg "~a0: width of ~a1 is ~x2; expected a positive ~
                           number."
                     :args (list inst (car ports)
                                 (and expr1 (vl-expr->finalwidth expr1)))
                     :fatalp t
                     :fn 'vl-module-port-widths)
                    warnings)
              nil))

         ((mv successp warnings cdr-sizes)
          (vl-module-port-widths (cdr ports) inst warnings))
         ((unless successp)
          (mv nil warnings nil)))

      (mv t warnings (cons width1 cdr-sizes))))

  (local (in-theory (enable vl-module-port-widths)))

  (defthm vl-warninglist-p-of-vl-module-port-widths
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 1 (vl-module-port-widths ports inst warnings)))))

  (defthm vl-module-port-widths-basics
    (let ((ret (vl-module-port-widths ports inst warnings)))
      (implies (mv-nth 0 ret)
               (and (pos-listp (mv-nth 2 ret))
                    (equal (len (mv-nth 2 ret)) (len ports)))))))




(defsection vl-assemble-modinsts
  :parents (replicate)
  :short "Build @(see vl-modinst-p)'s from the sliced-up arguments."

  :long "<p><b>Signature:</b> @(call vl-assemble-modinsts) returns a @(see
vl-modinstlist-p).</p>

<ul>

<li><tt>names</tt> are the names to give to the module instances.</li>

<li><tt>args</tt> are the sliced up arguments (see @(see
vl-replicate-arguments)).</li>

<li>The other arguments are taken from the original module instance that we are
slicing up.</li>

</ul>"

  (defund vl-assemble-modinsts (names args modname str delay atts loc)
    (declare (xargs :guard (and (string-listp names)
                                (vl-argumentlist-p args)
                                (same-lengthp names args)
                                (stringp modname)
                                (vl-maybe-gatestrength-p str)
                                (vl-maybe-gatedelay-p delay)
                                (vl-atts-p atts)
                                (vl-location-p loc))))
    (if (atom args)
        nil
      (cons (make-vl-modinst :instname (car names)
                             :modname modname
                             :str str
                             :delay delay
                             :atts atts
                             :portargs (car args)
                             :paramargs (vl-arguments nil nil) ;; BOZO think about this?
                             :loc loc)
            (vl-assemble-modinsts (cdr names) (cdr args) modname str delay atts loc))))

  (local (in-theory (enable vl-assemble-modinsts)))

  (defthm vl-modinstlist-p-of-vl-assemble-modinsts
    (implies (and (force (string-listp names))
                  (force (vl-argumentlist-p args))
                  (force (stringp modname))
                  (force (vl-maybe-gatestrength-p str))
                  (force (vl-maybe-gatedelay-p delay))
                  (force (vl-atts-p atts))
                  (force (vl-location-p loc)))
             (vl-modinstlist-p
              (vl-assemble-modinsts names args modname str delay atts loc)))))



(defsection vl-replicate-modinst
  :parents (replicate)
  :short "Convert a module instance into a list of simpler instances, if
necessary."

  :long "<p><b>Signature:</b> @(call vl-replicate-modinst) returns <tt>(mv
warnings new-modinsts new-nf)</tt>.</p>

<ul>

<li><tt>x</tt> is some module instance, which may have a range that we want
    to eliminate.</li>

<li><tt>mods</tt> and <tt>modalist</tt> are the global list of modules and
its corresponding @(see vl-modalist) for fast module lookups; we need this
to be able to determine the sizes of ports when we are slicing arguments.</li>

<li><tt>nf</tt> is a @(see vl-namefactory-p) for generating fresh names.</li>

<li><tt>warnings</tt> is an accumulator for warnings.</li>

</ul>

<p>If <tt>x</tt> has a range, i.e., it is an array of module instances,
then we try to split it into a list of <tt>nil</tt>-ranged, simple instances.
The <tt>new-modinsts</tt> should replace <tt>x</tt> in the module.</p>"

  (defund vl-replicate-modinst (x mods modalist nf mod warnings)
    "Returns (MV WARNINGS NEW-MODINSTS NF-PRIME)"
    (declare (xargs :guard (and (vl-modinst-p x)
                                (vl-modulelist-p mods)
                                (equal (vl-modalist mods) modalist)
                                (vl-namefactory-p nf)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))

    (b* ((range (vl-modinst->range x))

         ((unless range)
          ;; There isn't a range, so this is already an ordinary, non-array
          ;; instance.  We don't need to do anything, so return early.
          (mv warnings (list x) nf))

         (instname  (vl-modinst->instname x))
         (modname   (vl-modinst->modname x))
         (portargs  (vl-modinst->portargs x))
         (str       (vl-modinst->str x))
         (delay     (vl-modinst->delay x))
         (loc       (vl-modinst->loc x))
         (atts      (vl-modinst->atts x))

         ((unless (vl-range-resolved-p range))
          (mv (cons (make-vl-warning
                     :type :vl-bad-instance
                     :msg "~a0: instance array with unresolved range: ~a1."
                     :args (list x range)
                     :fatalp t
                     :fn 'vl-replicate-modinst)
                    warnings)
              (list x) nf))

         ;; We add an annotation saying that these instances are from an array.
         (atts (cons (list "VL_FROM_INST_ARRAY") atts))
         (size (vl-range-size range))

         (target (vl-fast-find-module modname mods modalist))
         ((unless target)
          (mv (cons (make-vl-warning
                     :type :vl-bad-instance
                     :msg "~a0: instance of undefined module ~m1."
                     :args (list x modname)
                     :fatalp t
                     :fn 'vl-replicate-modinst)
                    warnings)
              (list x) nf))

         ((mv successp warnings port-widths)
          (vl-module-port-widths (vl-module->ports target) x warnings))

         ((unless successp)
          ;; Already added a warning.
          (mv warnings (list x) nf))

         ((mv warnings new-args)
          (vl-replicate-arguments portargs port-widths size mod warnings))

         ((mv warnings names nf)
          (vl-replicated-instnames instname range nf x warnings))

         (new-modinsts
          (vl-assemble-modinsts names new-args modname str delay atts loc)))

        (mv warnings new-modinsts nf)))

  (defmvtypes vl-replicate-modinst (nil true-listp nil))

  (local (in-theory (enable vl-replicate-modinst)))

  (defthm vl-warninglist-p-of-vl-replicate-modinst
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 0 (vl-replicate-modinst x mods modalist nf mod warnings)))))

  (defthm vl-modinstlist-p-of-vl-replicate-modinst
    (implies (and (force (vl-modinst-p x))
                  (force (vl-modulelist-p mods))
                  (force (equal (vl-modalist mods) modalist))
                  (force (vl-namefactory-p nf))
                  (force (vl-module-p mod)))
             (vl-modinstlist-p
              (mv-nth 1 (vl-replicate-modinst x mods modalist nf mod warnings)))))

  (defthm vl-namefactory-p-of-vl-replicate-modinst
    (implies (and (force (vl-modinst-p x))
                  (force (vl-modulelist-p mods))
                  (force (equal (vl-modalist mods) modalist))
                  (force (vl-namefactory-p nf))
                  (force (vl-module-p mod)))
             (vl-namefactory-p
              (mv-nth 2 (vl-replicate-modinst x mods modalist nf mod warnings))))))



(defsection vl-replicate-modinstlist
  :parents (replicate)
  :short "Extend @(see vl-replicate-modinst) across a @(see vl-modinstlist-p)"

  :long "<p><b>Signature:</b> @(call vl-replicate-modinstlist) returns <tt>(mv
warnings x-prime nf-prime)</tt>.</p>"

  (defund vl-replicate-modinstlist (x mods modalist nf mod warnings)
    (declare (xargs :guard (and (vl-modinstlist-p x)
                                (vl-modulelist-p mods)
                                (equal (vl-modalist mods) modalist)
                                (vl-namefactory-p nf)
                                (vl-module-p mod)
                                (vl-warninglist-p warnings))))
    (b* (((when (atom x))
          (mv warnings nil nf))
         ((mv warnings car-insts nf)
          (vl-replicate-modinst (car x) mods modalist nf mod warnings))
         ((mv warnings cdr-insts nf)
          (vl-replicate-modinstlist (cdr x) mods modalist nf mod warnings)))
        (mv warnings (append car-insts cdr-insts) nf)))

  (defmvtypes vl-replicate-modinstlist (nil true-listp nil))

  (local (in-theory (enable vl-replicate-modinstlist)))

  (defthm vl-warninglist-p-of-vl-replicate-modinstlist
    (implies (force (vl-warninglist-p warnings))
             (vl-warninglist-p
              (mv-nth 0 (vl-replicate-modinstlist x mods modalist nf mod warnings)))))

  (defthm vl-modinstlist-p-of-vl-replicate-modinstlist
    (implies (and (force (vl-modinstlist-p x))
                  (force (vl-modulelist-p mods))
                  (force (equal (vl-modalist mods) modalist))
                  (force (vl-namefactory-p nf))
                  (force (vl-module-p mod)))
             (vl-modinstlist-p
              (mv-nth 1 (vl-replicate-modinstlist x mods modalist nf mod warnings)))))

  (defthm vl-namefactory-p-of-vl-replicate-modinstlist
    (implies (and (force (vl-modinstlist-p x))
                  (force (vl-modulelist-p mods))
                  (force (equal (vl-modalist mods) modalist))
                  (force (vl-namefactory-p nf))
                  (force (vl-module-p mod)))
             (vl-namefactory-p
              (mv-nth 2 (vl-replicate-modinstlist x mods modalist nf mod warnings))))))



(defsection vl-module-replicate
  :parents (replicate)
  :short "Eliminate gate and module instance arrays from a module."

  :long "<p><b>Signature:</b> @(call vl-module-replicate) returns an updated
module.</p>

<p><tt>x</tt> is the module to alter, <tt>mods</tt> is the global list of
modules, and <tt>modalist</tt> is the @(see vl-modalist) for <tt>mods</tt> for
fast lookups.  We produce a new version of <tt>x</tt> by eliminating any gate
or module instance arrays, and replacing them with explicit lists of
instances.</p>"

  (defund vl-module-replicate (x mods modalist)
    (declare (xargs :guard (and (vl-module-p x)
                                (vl-modulelist-p mods)
                                (equal modalist (vl-modalist mods)))))
    (b* (((when (vl-module->hands-offp x))
          x)
         (warnings   (vl-module->warnings x))
         (modinsts   (vl-module->modinsts x))
         (gateinsts  (vl-module->gateinsts x))
         (nf         (vl-starting-namefactory x))

         ((mv warnings new-gateinsts nf)
          (vl-replicate-gateinstlist gateinsts nf x warnings))

         ((mv warnings new-modinsts nf)
          (vl-replicate-modinstlist modinsts mods modalist nf x warnings))

         (- (vl-free-namefactory nf))

         (x-prime (change-vl-module x
                                    :modinsts new-modinsts
                                    :gateinsts new-gateinsts
                                    :warnings warnings)))
        x-prime))

  (local (in-theory (enable vl-module-replicate)))

  (defthm vl-module-p-of-vl-module-replicate
    (implies (and (force (vl-module-p x))
                  (force (vl-modulelist-p mods))
                  (force (equal modalist (vl-modalist mods))))
             (vl-module-p (vl-module-replicate x mods modalist))))

  (defthm vl-module->name-of-vl-module-replicate
    (equal (vl-module->name (vl-module-replicate x mods modalist))
           (vl-module->name x))))



(defsection vl-modulelist-replicate
  :parents (replicate)
  :short "Extend @(see vl-module-replicate) across the list of modules."

  (defprojection vl-modulelist-replicate-aux (x mods modalist)
    (vl-module-replicate x mods modalist)
    :guard (and (vl-modulelist-p x)
                (vl-modulelist-p mods)
                (equal modalist (vl-modalist mods)))
    :result-type vl-modulelist-p)

  (defthm vl-modulelist->names-of-vl-modulelist-replicate-aux
    (equal (vl-modulelist->names (vl-modulelist-replicate-aux x mods modalist))
           (vl-modulelist->names x))
    :hints(("Goal" :induct (len x))))

  (defund vl-modulelist-replicate (x)
    (declare (xargs :guard (vl-modulelist-p x)))
    (b* ((modalist (vl-modalist x))
         (result   (vl-modulelist-replicate-aux x x modalist))
         (-        (flush-hons-get-hash-table-link modalist)))
        result))

  (defthm vl-modulelist-p-of-vl-modulelist-replicate
    (implies (force (vl-modulelist-p x))
             (vl-modulelist-p (vl-modulelist-replicate x)))
    :hints(("Goal" :in-theory (enable vl-modulelist-replicate))))

  (defthm vl-modulelist->names-of-vl-modulelist-replicate
    (equal (vl-modulelist->names (vl-modulelist-replicate x))
           (vl-modulelist->names x))
    :hints(("Goal" :in-theory (enable vl-modulelist-replicate)))))

