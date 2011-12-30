; ACL2 String Library
; Copyright (C) 2009-2010 Centaur Technology
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

(in-package "STR")
(include-book "xdoc/top" :dir :system)
(include-book "tools/bstar" :dir :system)
(local (include-book "misc/assert" :dir :system))
(local (include-book "arithmetic"))

(defsection html-encoding
  :parents (str)
  :short "Routines to encode HTML entities such as &lt; and &amp; into
&amp;lt;, &amp;amp;, etc."

  :long "<p>In principle, our conversion routines may not be entirely
legitimate in the sense of some precise HTML specification, because we do not
account for non-printable characters or other similarly unlikely garbage in the
input.  But it seems like what we implement is pretty reasonable, and handles
most ordinary characters.</p>

<p>Note that we convert <tt>#\Newline</tt> characters into the sequence
<tt>&lt;br/&gt;#\Newline</tt>.  This may not be the desired behavior in certain
applications, but seems basically reasonable for converting plain text into
HTML.</p>")

(defconst *html-space*    (coerce "&nbsp;" 'list))
(defconst *html-newline*  (append (coerce "<br/>" 'list) (list #\Newline)))
(defconst *html-less*     (coerce "&lt;"   'list))
(defconst *html-greater*  (coerce "&gt;"   'list))
(defconst *html-amp*      (coerce "&amp;"  'list))
(defconst *html-quote*    (coerce "&quot;" 'list))

(defsection repeated-revappend

  (defund repeated-revappend (n x y)
    (declare (xargs :guard (and (natp n)
                                (true-listp x))))
    (if (zp n)
        y
      (repeated-revappend (- n 1) x (revappend x y))))

  (local (in-theory (enable repeated-revappend)))

  (defthm character-listp-of-repeated-revappend
    (implies (and (character-listp x)
                  (character-listp y))
             (character-listp (repeated-revappend n x y)))))

(encapsulate
 ()
 (local (include-book "arithmetic-3/floor-mod/floor-mod" :dir :system))

 (defund distance-to-tab (col tabsize)
   (declare (xargs :guard (and (natp col)
                               (posp tabsize))))
   (mbe :logic
        (nfix (- tabsize (rem col tabsize)))
        :exec
        (- tabsize (rem col tabsize)))))


(defsection html-encode-chars-aux
  :parents (html-encoding)
  :short "Convert a character list into HTML."
  :long "<p>@(call html-encode-chars-aux) converts the character-list <tt>x</tt>
into HTML, producing new characters which are accumulated onto <tt>acc</tt> in
reverse order.</p>

<p>As inputs:</p>
<ul>
 <li>X is a list of characters which we are currently transforming into HTML.</li>
 <li>Col is the current column number</li>
 <li>Acc is an ordinary character list, onto which we accumulate the encoded
     HTML characters, in reverse order.</li>
</ul>

<p>We return <tt>(mv col' acc')</tt>, where <tt>col'</tt> is the new column
number and <tt>acc'</tt> is the updated accumulator, which includes the HTML
encoding of <tt>X</tt> in reverse.</p>"

  (defund html-encode-chars-aux (x col tabsize acc)
    (declare (xargs :guard (and (character-listp x)
                                (natp col)
                                (posp tabsize)
                                (character-listp acc))))
    (if (atom x)
        (mv (mbe :logic (nfix col) :exec col)
            acc)
      (let ((char1 (car x)))
        (html-encode-chars-aux
         (cdr x)
         (cond ((eql char1 #\Newline)
                0)
               ((eql char1 #\Tab)
                (+ col (distance-to-tab col tabsize)))
               (t
                (+ 1 col)))
         tabsize
         (case char1
           ;; Cosmetic: avoid inserting &nbsp; unless the last char is a
           ;; space or newline.  This makes the HTML a little easier to
           ;; read.
           (#\Space   (if (or (atom acc)
                              (eql (car acc) #\Space)
                              (eql (car acc) #\Newline))
                          (revappend *html-space* acc)
                        (cons #\Space acc)))
           (#\Newline (revappend *html-newline* acc))
           (#\<       (revappend *html-less* acc))
           (#\>       (revappend *html-greater* acc))
           (#\&       (revappend *html-amp* acc))
           (#\"       (revappend *html-quote* acc))
           (#\Tab     (repeated-revappend (distance-to-tab col tabsize) *html-space* acc))
           (otherwise (cons char1 acc)))))))

  (local (in-theory (enable html-encode-chars-aux)))

  (defthm natp-of-html-encode-chars-aux
    (natp (mv-nth 0 (html-encode-chars-aux x col tabsize acc)))
    :rule-classes :type-prescription)

  (defthm character-listp-of-html-encode-chars-aux
    (implies (and (character-listp x)
                  (natp col)
                  (character-listp acc))
             (character-listp (mv-nth 1 (html-encode-chars-aux x col tabsize acc))))))


(defsection html-encode-string-aux
  :parents (html-encoding)
  :short "Convert a string into HTML."
  :long "<p>@(call html-encode-string-aux) returns <tt>(mv col acc)</tt>.</p>

<p>This is similar to @(see html-encode-chars-aux), but encodes part of a the
string <tt>x</tt> instead of a character list.  The additional arguments are as
follows:</p>

<ul>
<li><tt>xl</tt> - the pre-computed length of the string</li>
<li><tt>n</tt> - current position in the string where we are encoding; this
should typically be 0 to begin with.</li>
</ul>"

  (defund html-encode-string-aux (x n xl col tabsize acc)
    (declare (xargs :guard (and (stringp x)
                                (natp n)
                                (natp xl)
                                (natp col)
                                (posp tabsize)
                                (character-listp acc)
                                (<= n xl)
                                (= xl (length x)))
                    :measure (nfix (- (nfix xl) (nfix n))))
             (type string x)
             (type integer n xl col tabsize))
    (if (mbe :logic (zp (- (nfix xl) (nfix n)))
             :exec (= n xl))
        (mv (mbe :logic (nfix col) :exec col)
            acc)
      (let ((char1 (char x n)))
        (html-encode-string-aux
         x
         (mbe :logic (+ 1 (nfix n)) :exec (+ 1 n))
         xl
         (cond ((eql char1 #\Newline)
                0)
               ((eql char1 #\Tab)
                (+ col (distance-to-tab col tabsize)))
               (t
                (+ 1 col)))
         tabsize
         (case char1
           ;; Cosmetic: avoid inserting &nbsp; unless the last char is a
           ;; space or newline.  This makes the HTML a little easier to
           ;; read.
           (#\Space   (if (or (atom acc)
                              (eql (car acc) #\Space)
                              (eql (car acc) #\Newline))
                          (revappend *html-space* acc)
                        (cons #\Space acc)))
           (#\Newline (revappend *html-newline* acc))
           (#\<       (revappend *html-less* acc))
           (#\>       (revappend *html-greater* acc))
           (#\&       (revappend *html-amp* acc))
           (#\"       (revappend *html-quote* acc))
           (#\Tab     (repeated-revappend (distance-to-tab col tabsize) *html-space* acc))
           (otherwise (cons char1 acc)))
         ))))

  ;; Bleh.  Should probably prove they are equal, but whatever.
  (local (ACL2::assert! (b* ((x "blah
tab:	  <boo> & \"foo\" blah blah")
                             ((mv str-col str-ans)
                              (html-encode-string-aux x 0 (length x) 0 8 nil))
                             ((mv char-col char-ans)
                              (html-encode-chars-aux (coerce x 'list) 0 8 nil))
                             (- (cw "~s0~%" (coerce (reverse str-ans) 'string))))
                          (and (equal str-col char-col)
                               (equal str-ans char-ans)))))

  (local (in-theory (enable html-encode-string-aux)))

  (defthm natp-of-html-encode-string-aux
    (natp (mv-nth 0 (html-encode-string-aux x n xl col tabsize acc)))
    :rule-classes :type-prescription)

  (defthm character-listp-of-html-encode-string-aux
    (implies (and (stringp x)
                  (natp n)
                  (natp xl)
                  (natp col)
                  (character-listp acc)
                  (<= n xl)
                  (= xl (length x)))
             (character-listp (mv-nth 1 (html-encode-string-aux x n xl col tabsize acc))))))


(defsection html-encode-string
  :parents (html-encoding)
  :short "@(call html-encode-string) converts the string <tt>x</tt> into HTML,
and returns the result as a new string."

  (defund html-encode-string (x tabsize)
    (declare (xargs :guard (and (stringp x)
                                (posp tabsize)))
             (type string x)
             (type integer tabsize))
    (mv-let (col acc)
      (html-encode-string-aux x 0 (length x) 0 tabsize nil)
      (declare (ignore col))
      (reverse (coerce acc 'string))))

  (local (in-theory (enable html-encode-string)))

  (defthm stringp-of-html-encode-string
    (stringp (html-encode-string x tabsize))
    :rule-classes :type-prescription))

