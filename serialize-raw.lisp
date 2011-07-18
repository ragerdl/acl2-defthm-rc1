; ACL2 Version 4.2 -- A Computational Logic for Applicative Common Lisp
; Copyright (C) 2011  University of Texas at Austin

; This version of ACL2 is a descendent of ACL2 Version 1.9, Copyright
; (C) 1997 Computational Logic, Inc.  See the documentation topic
; NOTE-2-0.

; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

; Regarding authorship of ACL2 in general:

; Written by:  Matt Kaufmann               and J Strother Moore
; email:       Kaufmann@cs.utexas.edu      and Moore@cs.utexas.edu
; Department of Computer Science
; University of Texas at Austin
; Austin, TX 78701 U.S.A.

; serialize-raw.lisp -- a scheme for serializing ACL2 objects to disk.

; This file was developed and contributed by Jared Davis on behalf of
; Centaur Technology.

; Note: this file is currently only included as part of ACL2(h).  But
; it is independent of the remainder of the Hons extension and might
; some day become part of ordinary ACL2.

; Please direct correspondence about this file to Jared Davis
; <jared@centtech.com>.

(in-package "ACL2")



; INTRODUCTION
;
; We now develop a serialization scheme that allows ACL2 objects to be saved to
; disk using a compact, structure-shared, and essentially binary encoding.
;
; We configure ACL2's print-object$ function so that it writes objects with our
; encoding scheme when writing certificate files, so that large objects produced
; by make-event are encoded efficiently.
;
; We extend the ACL2 readtable so serialized objects can be read at any time,
; using the extended reader macros #z[...] and #Z[...].  These macros are almost
; identical.  The only difference is that when #z is used, we reconstruct the
; object entirely with CONS, whereas with #Z we use HONS for parts of the
; structure that were honsed to begin with.
;
; We provide routines for reading and writing ACL2 objects as individual files,
; typically with a ".sao" extension for "Serialized ACL2 Object".  But for
; bootstrapping reasons, these are introduced in hons.lisp and hons-raw.lisp
; instead of here in serialize-raw.lisp.



; ESSAY ON BAD OBJECTS AND SERIALIZE
;
; When we decode serialized objects, must we ensure that the object returned is
; a valid ACL2 object, i.e., not something that BAD-LISP-OBJECTP would reject?
;
; Matt and Jared think the answer is "no" for the reader macros.  Why?  These
; macros are just extensions of certain readtables like the *acl2-readtable*,
; which are used by READ to interpret input.  But there are already any number
; of other ways for READ to produce bad objects, for instance it might produce a
; floating point numbers, symbols in a foreign package, vectors, structures,
; etc.  The "Remarks on *acl2-readtable*" in acl2.lisp has more discussion of
; these matters.  At any rate, whenever ACL2 is using READ, it already needs to
; be defending against bad objects, so it should be okay if the serialize reader
; macros generate bad objects.
;
; However, Jared thinks that the serialize-read-fn function *is* responsible for
; ensuring that only good objects are read, because it is a "new" way for input
; to enter the system.
;
; Well, the serialized object format is considerably more restrictive than the
; Common Lisp reader, and does not provide any way to encode floats, circular
; objects, etc.  Jared thinks the only bad objects that can be produced from
; serialized reading are symbols in unknown packages.  So, in
; serialize-read-file we pass in a flag that makes sure we check whether
; packages are known.  We think this is sufficient to justify not checking
; BAD-LISP-OBJECTP explicitly.



; ESSAY ON THE SERIALIZE OBJECT FORMAT
;
; Our scheme involves encoding ACL2 objects into a fairly simple, byte-based,
; binary format.
;
; There are actually two different formats of serialized objects.  The older
; format is named v1, and the newer is v2.  We can currently read both formats,
; but we only support writing the newer format.
;
; Why do we have two versions?  We originally developed the serialization scheme
; as ttag-based library in :dir :system, but this left us with no way to tightly
; integrate it into ACL2's certificate printing and reading routines.  As we
; moved serialization into ACL2 proper, we noticed a few areas that we could
; improve, and made slight tweaks to the serialization scheme.  But this made
; our new version incompatible with books/serialize, and we already had many
; files written in the old format.
;
; There is probably no reason to write the old v1 files.  But if you want to do
; this, you can still load the books/serialize library and use its routines
; directly.
;
; Both versions are very similar, so it is not too hard to support them both.
; We first describe the v1 format:
;
;   OBJECT ::= MAGIC                       ; marker for sanity checking
;              LEN                         ; total number of objects
;              NATS RATS COMPLEXES CHARS   ; object data
;              STRS SYMBOLS CONSES         ;
;              MAGIC                       ; marker for sanity checking
;
;   NATS      ::= LEN NAT*        ; number of nats, followed by that many nats
;   RATS      ::= LEN RAT*        ; number of rats, followed by that many rats
;   COMPLEXES ::= LEN COMPLEX*    ; etc.
;   CHARS     ::= LEN CHAR*
;   STRS      ::= LEN STR*
;   PACKAGES  ::= LEN PACKAGE*
;   CONSES    ::= LEN CONS*
;
;   RAT ::= NAT NAT NAT           ; sign (0 or 1), numerator, denominator
;   COMPLEX ::= RAT RAT           ; real, imaginary parts
;   CHAR ::= byte                 ; the character code for this character
;   STR ::= LEN CHAR*             ; length and then its characters
;   PACKAGE ::= STR LEN STR*      ; package name, number of symbols, symbol names
;   CONS ::= NAT NAT              ; "index" of its car and cdr (see below)
;
;   LEN ::= NAT                   ; just to show when we're referring to a length
;
;   MAGIC ::= #xAC120BC7          ; also see the discussion below
;
;   NAT ::= [see below]
;
;
; Magic Numbers.  The magic number, #xAC120BC7, is a 32-bit integer that sort
; of looks like "ACL2 OBCT", i.e., "ACL2 Object."  This use of magic numbers is
; probably silly, but may have some advantages:
;
;   (1) It lets us do a basic sanity check.
;
;   (2) When serialize is used to write out whole files, helps to ensure the
;       file doesn't start with valid ASCII characters.  This *might* help
;       protect these files from tampering by programs that convert newline
;       characters in text files (e.g., FTP programs).
;
;   (3) It gives us the option of tweaking our encoding, e.g., we use magic
;       numbers to distinguish between v1 and v2 files, and in the future we
;       could add additional encodings by adding other magic numbers.
;
;
; Naturals.  Our representation of NAT is slightly involved since we need to
; support arbitrary-sized natural numbers.  We use a variable-length encoding
; where the most significant bit of each byte is 0 if this is the last piece of
; the number, or 1 if there are additional bytes, and the other 7 bits are data
; bits.  The bytes are kept in little-endian order.  For example:
;
;      0 is encoded as   #x00       (continue bit: 0, data: 0)
;      2 is encoded as   #x02       (continue bit: 0, data: 2)
;       ...
;      127 is encoded as #x7F       (continue bit: 0, data: 127)
;      128 is encoded as #x80 #x01  [(continue bit: 1, data: 1) = 1] + 127*[(c: 0, d: 1) = 1]
;      129 is encoded as #x81 #x01  [(continue bit: 1, data: 2) = 2] + 127*[(c: 0, d: 1) = 1]
;       ...
;
;
; Negative Integers.  Negative integers aren't mentioned in the file format
; because we encode them as rationals with denominator 1.  This only requires 2
; bytes of overhead (for the sign and denominator) beyond the magnitude of the
; integer, which seems acceptable since negative integers aren't especially
; frequent.
;
;
; Conses.  Every object in the file has an (implicit) index, determined by its
; position in the file.  The naturals are given the smallest indexes 0, 1, 2,
; and so on.  Supposing there are N naturals, the rationals will have indexes
; N, N+1, etc.  After that we have the complexes, then the characters, strings,
; symbols, and finally the conses.
;
; We encode conses using these indices.  For instance, suppose the first two
; natural numbers in our file are 37 and 55.  Since we start our indexing with
; the naturals, 37 will have index 0 and 55 will have index 1.  Then, we can
; encode the cons (37 . 55) by just writing down these two indices, e.g., #x00
; #x01.
;
; We insist that sub-trees of conses come first in the file, so as we are
; decoding the file, whenever we construct a cons we can make sure its indices
; refer to already-constructed conses.
;
; The object with the maximal index in the "the object" that has been saved,
; and is returned by the #z and #Z readers, or by the whole-file reader.
;
;
; The V2 format.  The V2 format is almost the same as the V1 format, but with
; the following changes:
;
;   (1) The magic number changes to #xAC120BC8, so we know which format is
;       being used,
;
;   (2) We tweak the way indices are handled so that NIL and T are implicitly
;       given index 0 and 1, respectively, which can sometimes slightly improve
;       compression for cons structures that have lots of NILs and Ts within
;       them.
;
;   (3) We change the way conses are represented so we can mark which conses
;       were normed.  Instead of recording a cons by writing down its car-index
;       and cdr-index verbatim, we now instead write down:
;
;           (car-index << 1) | (if honsp 1 0), cdr-index
;
;       Because of the way we encode naturals, this neatly only costs an extra
;       byte if the car-index happens to have an integer length that is a
;       multiple of 7.
;
;   (4) Instead of the total number of objects, we replace LEN with the maximum
;       index of the object to be read.  Usually this just means that instead of
;       LEN we record LEN-1.  But it allows us to detect the special case of NIL
;       where the object being encoded is not necessarily at LEN - 1.




; -----------------------------------------------------------------------------
;
;                              PRELIMINARIES
;
; -----------------------------------------------------------------------------

(defparameter *ser-verbose* nil)

(defmacro ser-time? (form)
  `(if *ser-verbose*
       (time ,form)
     ,form))

(defmacro ser-print? (msg &rest args)
  `(when *ser-verbose*
     (format t ,msg . ,args)))



; To make it easy to switch the kind of input/output stream being used, all of
; our stream reading/writing is done with the following macros.
;
; In previous versions of serialize we used binary streams and wrote/read from
; them with write/read-byte on most Lisps; on CCL we used memory-mapped files
; for better performance while reading.  But we had to switch to using ordinary
; character streams to get compatibility with the Common Lisp reader.

(defmacro ser-write-char (x stream)
  `(write-char (the character ,x) ,stream))

(defmacro ser-write-byte (x stream)
  `(ser-write-char (code-char (the (unsigned-byte 8) ,x)) ,stream))

(defmacro ser-read-char (stream)
  ;; Note that read-char causes an end-of-file error if EOF is reached, so we
  ;; don't have to try to detect unexpected EOFs in our decoding routines.
  `(the character (read-char ,stream)))

(defmacro ser-read-byte (stream)
  `(the (unsigned-byte 8) (char-code (ser-read-char ,stream))))

(defun ser-encode-magic (stream)
  ;; We only write V2 files now, so we write AC120BC8 instead of C7.
  (ser-write-byte #xAC stream)
  (ser-write-byte #x12 stream)
  (ser-write-byte #x0B stream)
  (ser-write-byte #xC8 stream))

(defun ser-decode-magic (stream)
  ;; Returns :V1 or :V2, or causes an error.
  (let* ((magic-1 (ser-read-byte stream))
         (magic-2 (ser-read-byte stream))
         (magic-3 (ser-read-byte stream))
         (magic-4 (ser-read-byte stream)))
    (declare (type (unsigned-byte 8) magic-1 magic-2 magic-3 magic-4))
    (let ((version (and (= magic-1 #xAC)
                        (= magic-2 #x12)
                        (= magic-3 #x0B)
                        (cond ((= magic-4 #xC7) :v1)
                              ((= magic-4 #xC8) :v2)
                              (t nil)))))
      (unless version
        (error "Invalid serialized object, magic number incorrect."))
      version)))



; -----------------------------------------------------------------------------
;
;                      ENCODING AND DECODING NATURALS
;
; -----------------------------------------------------------------------------

; WHY DO WE USE 8-BIT BLOCKS?
;
; Originally I tried using 64-bit blocks.  I thought this would mean only 1/64
; of the bits would be "overhead" for continue-bits, and surely this would be
; better than using 8-bit blocks, where 1/8 of the bits would be continue-bit
; overhead.
;
; This thinking is totally wrong.  It ignores another important source of
; overhead: the unnecessary data-bits in the final block.  To make this very
; concrete, think about encoding the number 5.  We only "need" 3 bits.  In an
; 8-bit encoding, we use 8 bits so the overhead is 5/8 = 62%.  But in a 64-bit
; encoding we would need 64 bits for an overhead of 61/64 = 95%.  So the 8-bit
; encoding is much more efficient for small integers.
;
; Of course, there are cases where 64-bit blocks win.  For instance, 2^62 nicely
; fits into a single 64-bit block, but requires 9 8-bit blocks (at 7 data bits
; apiece), i.e., 72 bits.  But on some other larger numbers, 8-bit blocks can
; still be more efficient.  Take 2^64.  Here, we need either 2 64-bit blocks (at
; 63 data bits apiece) for 128 bits, or 10 8-bit blocks for 80 bits.  In short,
; the wider encoding only wins when there aren't very many unnecessary data bits
; in the final block.


; WHY ALL THESE OPTIMIZATIONS?
;
; The performance of natural number encoding/decoding is especially important
; because we have to (1) encode/decode two naturals for every cons, and (2)
; encode/decode naturals all over the place for string lengths, symbol name
; lengths, and the representation of any number.  These optimizations are a big
; deal: on one example benchmark, they improve CCL's decoding performance by
; almost 20%.

(defun ser-encode-nat-fixnum (n stream)

; Optimized encoder that assumes N is a fixnum.

  (declare (type fixnum n))
  (loop while (>= n 128)
        do
        (ser-write-byte (the fixnum (logior
                                     ;; The 7 low data bits
                                     (the fixnum (logand (the fixnum n) #x7F))
                                     ;; A continue bit
                                     #x80))
                        stream)
        (setq n (the fixnum (ash n -7))))
  (ser-write-byte n stream))

(defun ser-encode-nat-large (n stream)

; Safe encoder that doesn't assume how large N is.

  (declare (type integer n))
  (loop until (typep n 'fixnum)
        do
        ;; Fixnums are at least (signed-byte 16) in Common Lisp, so we must
        ;; be in the large case, i.e., n > 128.
        (ser-write-byte (the fixnum (logior
                                     ;; The 7 low data bits
                                     (the fixnum (logand (the integer n) #x7F))
                                     ;; A continue bit
                                     #x80))
                        stream)
        (setq n (the integer (ash n -7))))
  (ser-encode-nat-fixnum n stream))

(defmacro ser-encode-nat (n stream)

; This is kind of silly, but it lets us avoid the function overhead of calling
; ser-encode-nat-large in the very common case that N is a fixnum.

  `(let ((n ,n))
     (if (typep n 'fixnum)
         (ser-encode-nat-fixnum n ,stream)
       (ser-encode-nat-large n ,stream))))



(defun ser-decode-nat-large (shift value stream)

; Simple (but unoptimized) natural number decoder that doesn't assume anything
; is a fixnum.  Shift is 7 times the current block number we are reading, and
; represents how much we need to shift over the next 7 bits we read.  Value is
; the already-summed value of the previous blocks we have read.

  (let ((x1 (ser-read-byte stream)))
    (declare (type fixnum x1)
             (type integer value shift))
    (loop while (>= x1 128)
          do
          (incf value (ash (- x1 128) shift))
          (incf shift 7)
          (setf x1 (ser-read-byte stream)))
    (incf value (ash x1 shift))
    value))

(defmacro ser-decode-nat-body (shift)

; See SER-NAT-DECODE; this is accounting for different fixnum sizes across Lisps
; by unrolling the loop with a recursive macro.  SHIFT is a constant that is
; being incremented by 7 on each "iteration".  An invariant that is important to
; the fixnum optimizations is that VALUE is always less than 2^SHIFT.

  (if (> (expt 2 (+ 7 shift)) most-positive-fixnum)
      ;; Can't unroll any further because we've reached the fixnum size, so fall
      ;; back to using the large decoder.
      `(ser-decode-nat-large ,shift value stream)

    `(progn
       (setq x1 (ser-read-byte stream))

       ;; Reusing X1 is kind of goofy, but seems to result in better code on
       ;; CCL.
       (cond
        ((< x1 128)
         ;; The returned VALUE + (X1 << SHIFT) is a fixnum since it is less than
         ;; 2^(7+SHIFT), which above we checked is a fixnum.
         (setq x1 (the fixnum (ash (the fixnum x1) ,shift)))
         (the fixnum (+ value x1)))

        (t
         ;; Else, we increment value by (x1 - 128) << SHIFT.  This is still a
         ;; fixnum because (x1 - 128) < 2^7, so the sum is under 2^(7+SHIFT).
         (setq x1 (the fixnum (- x1 128)))
         (setq x1 (the fixnum (ash x1 ,shift)))
         (setq value (the fixnum (+ value x1)))

         ;; Recursive macro expansion to unroll further.
         (ser-decode-nat-body ,(+ 7 shift)))))))

(defun ser-decode-nat (stream)

; Optimized natural-number decoder.  For small enough integers (under 128) we
; don't need any shifting nonsense or even an accumulator.  For anything larger,
; we set up the initial VALUE accumulator and use our macro to write an
; unrolled, fixnum-optimized loop for us.

  (let ((x1 (ser-read-byte stream)))
    (declare (type fixnum x1))
    (when (< (the fixnum x1) 128)
      (return-from ser-decode-nat x1))
    (setq x1 (the fixnum (- x1 128)))
    (let ((value x1))
      (declare (fixnum value))
      (ser-decode-nat-body 7))))




; -----------------------------------------------------------------------------
;
;                 ENCODING AND DECODING OTHER BASIC OBJECTS
;
; -----------------------------------------------------------------------------

; RAT ::= NAT NAT NAT           ; sign (0 or 1), numerator, denominator

(declaim (inline ser-encode-rat ser-decode-rat))

(defun ser-encode-rat (x stream)
  (declare (type rational x))
  (ser-encode-nat (if (< x 0) 1 0) stream)
  (ser-encode-nat (abs (numerator x)) stream)
  (ser-encode-nat (denominator x) stream))

(defun ser-decode-rat (stream)
  (let* ((sign        (ser-decode-nat stream))
         (numerator   (ser-decode-nat stream))
         (denominator (ser-decode-nat stream)))
    (declare (type integer sign numerator denominator))

    (cond ((= sign 1)
           (setq numerator (- numerator)))
          ((= sign 0)
           ;; Fine, but there is nothing to do.
           nil)
          (t
           ;; This check probably isn't necessary; we could just assume that the
           ;; sign is zero.  But it seems cheap enough and basically reasonable.
           (error "Trying to decode rational, but the sign is invalid.")))

    (when (= denominator 0)
      ;; This check probably isn't necessary since the Lisp should probably an
      ;; error if we try to divide by zero, but it seems cheap enough and is
      ;; probably basically reasonable.
      (error "Trying to decode rational, but the denominator is zero."))

    (the rational (/ numerator denominator))))


; COMPLEX ::= RAT RAT           ; real, imaginary parts

(declaim (inline ser-encode-complex ser-decode-complex))

(defun ser-encode-complex (x stream)
  (declare (type complex x))
  (ser-encode-rat (realpart x) stream)
  (ser-encode-rat (imagpart x) stream))

(defun ser-decode-complex (stream)
  (let* ((realpart (ser-decode-rat stream))
         (imagpart (ser-decode-rat stream)))
    (declare (type rational realpart imagpart))
    (when (= imagpart 0)
      ;; Hrmn.  This check is probably unnecessary.  (complex 3 0) is just 3.
      ;; Our encoder should never encode natural numbers as complexes, but it
      ;; wouldn't necessarily be wrong to do so.
      (error "Trying to decode complex, but the imagpart is zero."))
    (complex realpart imagpart)))



; STR ::= LEN CHAR*             ; length and then its characters

; Note that our symbol encoding/decoding stuff piggy-backs on our string stuff,
; so we care about string encoding/decoding performance a bit.
;
; A very minor note is that in Common Lisp, the length of a string must be a
; fixnum (a string is a specialized vector, which is a one-dimensional array,
; and hence its size must be less than the array-dimension-limit, which is a
; fixnum.)

(declaim (inline ser-encode-str ser-decode-str))

(defun ser-encode-str (x stream)
  (declare (type string x))
  (let ((len (length x)))
    (ser-encode-nat-fixnum len stream)
    (loop for n fixnum from 0 below (the fixnum len) do
          (ser-write-char (char x n) stream))))

(defun ser-decode-str (stream)
  (let ((len (ser-decode-nat stream)))
    (unless (and (typep len 'fixnum)
                 (< (the fixnum len) array-dimension-limit))
      (error "Trying to decode a string, but the length is too long."))
    (let ((str (make-string (the fixnum len))))
      (declare (type vector str))
      (loop for i fixnum from 0 below (the fixnum len) do
            (setf (schar str i) (ser-read-char stream)))
      str)))




; -----------------------------------------------------------------------------
;
;                    ENCODING AND DECODING BASIC OBJECT LISTS
;
; -----------------------------------------------------------------------------

; We now build upon our encoders/decoders for individual elements, and write
; versions to deal with lists of naturals, rationals, etc.


(defstruct ser-decoder

; The decoder's state mainly consists of an ARRAY and a FREE index.  As the file
; is decoded, ARRAY gets populated from zero on up, with FREE always pointing to
; the next available slot.  Since array sizes are always fixnums, we know that
; FREE is always a fixnum.

  (array (make-array 0) :type simple-vector)
  (free  0              :type fixnum)

; The decoder also knows which file format we are decoding (either :v1 or :v2).
; This is set based on the magic number from the start of the file.

  (version nil))



; NATS ::= LEN NAT*        ; number of nats, followed by that many nats

(defun ser-encode-nats (x stream)
  (let ((len (length x)))
    (ser-print? "; Encoding ~a naturals.~%" len)
    (ser-encode-nat len stream)
    (dolist (elem x)
      (ser-encode-nat elem stream))))

(defun ser-decode-and-load-nats (decoder stream)
  (declare (type ser-decoder decoder))
  (let* ((len  (ser-decode-nat stream))
         (arr  (ser-decoder-array decoder))
         (free (ser-decoder-free decoder))
         (stop (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a naturals.~%" len)
    (unless (<= stop (length arr))
      ;; Note that we need just one bounds check for the whole list of naturals.
      (error "Invalid serialized object, too many naturals."))
    (loop until (= (the fixnum stop) free) do
          (setf (svref arr free) (ser-decode-nat stream))
          (incf free))
    (setf (ser-decoder-free decoder) stop)))



; RATS ::= LEN RAT*        ; number of rats, followed by that many rats

(defun ser-encode-rats (x stream)
  (let ((len (length x)))
    (ser-print? "; Encoding ~a rationals.~%" len)
    (ser-encode-nat len stream)
    (dolist (elem x)
      (ser-encode-rat elem stream))))

(defun ser-decode-and-load-rats (decoder stream)
  (declare (type ser-decoder decoder))
  (let* ((len  (ser-decode-nat stream))
         (arr  (ser-decoder-array decoder))
         (free (ser-decoder-free decoder))
         (stop (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a rationals.~%" len)
    (unless (<= stop (length arr))
      (error "Invalid serialized object, too many rationals."))
    (loop until (= (the fixnum stop) free) do
          (setf (svref arr free) (ser-decode-rat stream))
          (incf free))
    (setf (ser-decoder-free decoder) stop)))



; COMPLEXES ::= LEN COMPLEX*   ; number of complexes, followed by that many complexes

(defun ser-encode-complexes (x stream)
  (let ((len (length x)))
    (ser-print? "; Encoding ~a complexes.~%" len)
    (ser-encode-nat len stream)
    (dolist (elem x)
      (ser-encode-complex elem stream))))

(defun ser-decode-and-load-complexes (decoder stream)
  (declare (type ser-decoder decoder))
  (let* ((len  (ser-decode-nat stream))
         (arr  (ser-decoder-array decoder))
         (free (ser-decoder-free decoder))
         (stop (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a complexes.~%" len)
    (unless (<= stop (length arr))
      (error "Invalid serialized object, too many complexes."))
    (loop until (= (the fixnum stop) free) do
          (setf (svref arr free) (ser-decode-complex stream))
          (incf free))
    (setf (ser-decoder-free decoder) stop)))



; CHARS ::= LEN CHAR*     ; number of characters, followed by that many chars

(defun ser-encode-chars (x stream)
  (let ((len (length x)))
    (ser-print? "; Encoding ~a characters.~%" len)
    (ser-encode-nat len stream)
    (dolist (elem x)
      (ser-write-char elem stream))))

(defun ser-decode-and-load-chars (decoder stream)
  (declare (type ser-decoder decoder))
  (let* ((len  (ser-decode-nat stream))
         (arr  (ser-decoder-array decoder))
         (free (ser-decoder-free decoder))
         (stop (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a characters.~%" len)
    (unless (<= stop (length arr))
      (error "Invalid serialized object, too many characters."))
    (loop until (= (the fixnum stop) free) do
          (setf (svref arr free) (ser-read-char stream))
          (incf free))
    (setf (ser-decoder-free decoder) stop)))



; STRS ::= LEN STR*      ; number of strings, followed by that many strs

(defun ser-encode-strs (x stream)
  (let ((len (length x)))
    (ser-print? "; Encoding ~a strings.~%" len)
    (ser-encode-nat len stream)
    (dolist (elem x)
      (ser-encode-str elem stream))))

(defun ser-decode-and-load-strs (decoder stream)
  (declare (type ser-decoder decoder))
  (let* ((len  (ser-decode-nat stream))
         (arr  (ser-decoder-array decoder))
         (free (ser-decoder-free decoder))
         (stop (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a strings.~%" len)
    (unless (<= stop (length arr))
      (error "Invalid serialized object, too many strings."))
    (loop until (= (the fixnum stop) free) do
          (setf (svref arr free) (ser-decode-str stream))
          (incf free))
    (setf (ser-decoder-free decoder) stop)))




; -----------------------------------------------------------------------------
;
;                      ENCODING AND DECODING SYMBOLS
;
; -----------------------------------------------------------------------------

; We don't want to pay the price of writing down the package for every symbol
; individually, since most of the time an object will probably contain lots of
; symbols from the same package.  So, our basic approach is to organize the
; symbols into groups by their package names, and then for each package we write
; out: the name of the package, and the list of symbol names.
;
; See also the Essay on Bad Objects and Serialize.  When we are decoding, we
; optionally check that packages are known to ACL2 by calling pkg-witness, which
; causes an error if it the package isn't known.  Note that we only have to do
; this once per package, so this is a very low-cost check.
;
; If checking packages is so cheap, why not just check packages all the time?
; We tried that originally, but sometimes ACL2 actually DOES read in bad
; objects, e.g., foo@expansion.lsp may have *1* symbols in it, etc.  So we need
; to not complain if ACL2 is using the #z readers when reading these files.


; PACKAGE ::= STR LEN STR*      ; package name, number of symbols, symbol names

(defun ser-encode-package (pkg x stream)
  (declare (type string pkg))
  (let ((len (length x)))
    (ser-print? "; Encoding ~a symbols for ~a package.~%" len pkg)
    (ser-encode-str pkg stream)
    (ser-encode-nat (length x) stream)
    (dolist (elem x)
      (ser-encode-str (symbol-name elem) stream))))

(defun ser-decode-and-load-package (check-packagesp decoder stream)
  (declare (type ser-decoder decoder))
  (let* ((pkg-name (ser-decode-str stream))
         (len      (ser-decode-nat stream))
         (arr      (ser-decoder-array decoder))
         (free     (ser-decoder-free decoder))
         (stop     (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a symbols for ~a package.~%" len pkg-name)
    (unless (<= stop (length arr))
      (error "Invalid serialized object, too many symbols."))
    (when check-packagesp
      (acl2::pkg-witness pkg-name))
    (loop until (= (the fixnum stop) free) do
          (setf (svref arr free) (intern (ser-decode-str stream) pkg-name))
          (incf free))
    (setf (ser-decoder-free decoder) stop)))

; PACKAGES ::= LEN PACKAGE*    ; number of packages, followed by that many packages

(defun ser-encode-packages (alist stream)
  ;; Alist maps package-names to the lists of their symbols
  (let ((len (length alist)))
    (ser-print? "; Encoding symbols for ~a packages.~%" len)
    (ser-encode-nat (length alist) stream)
    (dolist (entry alist)
      (ser-encode-package (car entry) (cdr entry) stream))))

(defun ser-decode-and-load-packages (check-packagesp decoder stream)
  (declare (type ser-decoder decoder))
  (let ((len (ser-decode-nat stream)))
    (ser-print? "; Decoding symbols for ~a packages.~%" len)
    (loop for i from 1 to len do
          (ser-decode-and-load-package check-packagesp decoder stream))))




; -----------------------------------------------------------------------------
;
;                      PREPARING OBJECTS FOR ENCODING
;
; -----------------------------------------------------------------------------

(defun ser-hashtable-init (size test)

; For good performance, it is critical that we aggressively resize the hash
; tables that are used in the atom-gathering phase of encoding.  This is just a
; wrapper for making hash tables with more aggressive rehash sizes.

  (make-hash-table :size size
                   :test test
                   :rehash-size 2.2
                   #+Clozure :shared #+Clozure nil
                   ))


(defstruct ser-encoder

; This object bundles the state of the encoder.
;
; The first phase of encoding is SER-GATHER-ATOMS.  The goal is to quickly
; collect all of the atoms in the object, without duplication, and partition
; them into lists by their types.
;
; To avoid repeatedly collecting the same atoms, we use four "seen" tables that
; keep track of which objects we have explored.  As we gather atoms, we mark the
; objects we have seen by binding them to T in the appropriate hash table.
;
; Every symbol we have seen is in the SYM hash table, and every number/character
; we have seen is in the EQL hash table.  But the string and cons tables are
; only EQ hash tables.  Because of this, EQUAL-but-not-EQ strings and conses may
; be bound in their seen tables.
;
; We originally tried to use an EQUAL hash table for strings, but its
; performance was too slow.  We now take some special efforts (after gathering
; atoms) to avoid writing out multiple copies of duplicated strings.  But we
; don't try to avoid redundantly writing conses.  (Of course, a HONS user could
; first hons-copy their object to achieve full structure sharing.)

  (seen-sym  (ser-hashtable-init 1000 'eq)  :type hash-table)
  (seen-eql  (ser-hashtable-init 1000 'eql) :type hash-table)
  (seen-str  (ser-hashtable-init 1000 'eq)  :type hash-table)
  (seen-cons (ser-hashtable-init 2000 'eq) :type hash-table)


; In addition to the above seen tables, the encoder has several accumulators
; which collect the atoms it finds during the GATHER-ATOMS phase.  The basic
; idea here is to separate these objects by their types, so that we can then
; write them out using our encoders for lists of naturals, rationals, etc.
;
; The accumulators for naturals, rationals, complexes, strings, and characters
; are simple lists that we push new values into.  Because of our seen-tables, we
; can guarantee that the accumulators for naturals, rationals, complexes, and
; characters have no duplicates.  However, the strings accumulator may contain
; duplicates in the sense of EQUAL.

  (naturals     nil :type list)
  (rationals    nil :type list)
  (complexes    nil :type list)
  (chars        nil :type list)
  (strings      nil :type list)

; The symbol accumulator is more complex.  The SYMBOL-HT is a hash table that
; associates packages with the lists of symbols found in that package.  Once we
; are done gathering atoms, we map over this hash table to convert it into an
; alist (SYMBOL-AL).  This conversion is cheap; it only requires one cons per
; package.

  (symbol-ht    (ser-hashtable-init 60 'eq) :type hash-table)
  (symbol-al    nil :type list)


; The free-index here is only used in ser-encode-conses.  Bundling it with the
; encoder's state is beneficial in two ways for ser-encode-conses: it reduces
; stack size requirements by eliminating a parameter, and simplifies the flow
; because we don't need to return multiple values.

  (free-index  0 :type fixnum)

; The stream that we are writing into.  Bundling this into the encoder instead
; of passing it as an extra argument helps to reduce the stack size
; requirements for ser-encode-conses.

  (stream nil)

)

(defmacro ser-see-obj (x table)
  ;; Mark X as seen, and return T/NIL based on whether it was previously seen
  `(let ((x   ,x)
         (tbl ,table))
     (if (gethash x tbl)
         t
       (progn
         (setf (gethash x tbl) t)
         nil))))



; Gathering atoms is particularly performance critical, so we have looked into
; making it faster.  We assume X is a valid ACL2 object.  We do some typep
; checks in a few cases where using ordinary recognizers seems to be slower.
; But this does not gain us much, because almost all of the time seems to be
; spent on hashing.
;
; Sol uses a destructive hashing scheme in his AIGER writer which we could
; probably adapt for use here, and it would probably lead to significant
; performance gains.  However, anything destructive is scary with respect to
; multithreaded code, and we don't want to use it unless we really have no
; other choice.


(defun ser-gather-atoms (x encoder)
  (declare (type ser-encoder encoder))
  (cond ((consp x)
         (unless (ser-see-obj x (ser-encoder-seen-cons encoder))
           (ser-gather-atoms (car x) encoder)
           (ser-gather-atoms (cdr x) encoder)))

        ((symbolp x)
         ;; V2 change: do not gather T and NIL into the accumulator for
         ;; symbols.  They are implicit in the v2 format.
         (unless (or (eq x t)
                     (eq x nil)
                     (ser-see-obj x (ser-encoder-seen-sym encoder)))
           (push x (gethash (symbol-package x)
                            (ser-encoder-symbol-ht encoder)))))

        ((typep x 'fixnum)
         ;; This is probably common enough to check explicitly even though with
         ;; our fast check.
         (unless (ser-see-obj x (ser-encoder-seen-eql encoder))
           (if (< (the fixnum x) 0)
               (push x (ser-encoder-rationals encoder))
             (push x (ser-encoder-naturals encoder)))))

        ((typep x 'array) ; <-- (stringp x), but twice as fast in CCL.
         (unless (ser-see-obj x (ser-encoder-seen-str encoder))
           (push x (ser-encoder-strings encoder))))

        ;; Performance is probably already pretty bad at this point.
        (t
         (unless (ser-see-obj x (ser-encoder-seen-eql encoder))
           (cond ((typep x 'character)
                  (push x (ser-encoder-chars encoder)))
                 ((typep x 'integer)
                  (if (< x 0)
                      (push x (ser-encoder-rationals encoder))
                    (push x (ser-encoder-naturals encoder))))
                 ((rationalp x)
                  (push x (ser-encoder-rationals encoder)))
                 ((complex-rationalp x)
                  (push x (ser-encoder-complexes encoder)))
                 (t
                  (error "ser-gather-atoms-types given non-ACL2 object.")))))))



; After the atoms have been gathered we want to assign them unique indexes.
; These indexes will need to agree with the implicit order of the indexes in
; the serialized file.  So, we need to assign indexes to the naturals first,
; then the rationals, etc.
;
; In earlier versions of serialize, we constructed "atom map" structures that
; were hash tables binding atoms to their indices.  These atom maps were new
; structures that were unrelated to the seen-tables above.
;
; But now, for considerably better performance and memory efficiency, we
; instead smash the seen-tables and convert them into index mappings.  That is,
; during SER-GATHER-ATOMS above, the seen tables just bound the objects we had
; seen to T.  Now we are going to smash these bindings and replace them with
; their indices.  This is especially efficient because their hash tables have
; already been grown to the proper sizes.
;
; Before we this smashing process, we check that the maximum index we will ever
; need is going to be a fixnum.  Because of this, throughout this code we can
; assume that all indices are always fixnums.
;
; Future optimization optential.  It might be possible to do the index
; assignment inline with atom gathering, by keeping separate track of how many
; naturals we have seen, how many characters, etc., and storing only
; type-relative offsets into the atom maps instead of absolute indices.  I'm
; not sure if this would be much faster.  It might be particularly tricky to do
; correctly for strings.

(defun ser-make-atom-map-for-strings
  (x          ; The list of strings we gathered, which we are recurring down
   free-index ; Next available index that hasn't been assigned yet
   seen-str   ; The seen-str table; we are smashing it's T's with indexes.
   acc        ; Accumulator for unique strings
   )
  "Returns (VALUES UNIQUE-X FREE-INDEX')"
  (declare (type hash-table seen-str)
           (fixnum free-index))

; We do something pretty tricky for strings.
;
; To avoid EQUAL hashing, we only used an EQ seen table to detect whether
; strings had already been seen when we gathered atoms.  So our accumulated
; strings may have various EQUAL-but-not-EQ duplicates.  We can "implicitly"
; get rid of these duplicates by building our atom map in a funny way.
;
; This function is called with X = (sort gathered-strings #'string<).  Note
; that in Common Lisp, SORT is a stable sort.  Because of this, we only need to
; look at adjacent strings to see if they are EQUAL-but-not-EQ.
;
; We assign an index to every string we have gathered, but here is a trick: if
; the string is EQUAL to its neighbor, we do not increment the free-index and
; we do not add the string to our answer accumulator.
;
; In other words, given a list like ("foo" "foo" "bar") of non-EQ strings, we
; will assign the first two "foo"s to the same index, and "bar" to the next
; index.  But we still bind both copies of "foo" to the same index.  This way,
; when SER-ENCODE-CONSES wants to look up a string, it can still do an EQ
; lookup into the string table and find the appropriate index.
;
; We smash the atom seen-str table and return a sub-list of X where all the
; duplicates have been eliminated and where the strings are put into the right
; order for the indexes we have assigned them.

  (cond ((null x)
         (values free-index (nreverse acc)))
        (t
         ;; In all cases, add an entry for the first string.
         (setf (gethash (first x) seen-str) free-index)
         (if (or (null (cdr x))
                 (not (equal (first x) (second x))))
             ;; Not (STR1 STR1 ...), so increment and keep going
             (ser-make-atom-map-for-strings (cdr x)
                                        (the fixnum (+ 1 free-index))
                                        seen-str
                                        (cons (car x) acc))
           ;; (STR1 STR1 ...), so treat it as (STR1 ...)
           (ser-make-atom-map-for-strings (cdr x) free-index seen-str acc)))))

(defun ser-make-atom-map (encoder)

  ;; Note: this order must agree with ser-encode-main.

  (let ((free-index 2)
        ;; In v2, the first free index is 2 (nil and t are implicitly 0 and 1)
        (seen-sym (ser-encoder-seen-sym encoder))
        (seen-eql (ser-encoder-seen-eql encoder))
        (seen-str (ser-encoder-seen-str encoder)))
    (declare (fixnum free-index)
             (type hash-table seen-sym seen-eql seen-str))

    (dolist (elem (ser-encoder-naturals encoder))
      (setf (gethash elem seen-eql) free-index)
      (incf free-index))

    (dolist (elem (ser-encoder-rationals encoder))
      (setf (gethash elem seen-eql) free-index)
      (incf free-index))

    (dolist (elem (ser-encoder-complexes encoder))
      (setf (gethash elem seen-eql) free-index)
      (incf free-index))

    (dolist (elem (ser-encoder-chars encoder))
      (setf (gethash elem seen-eql) free-index)
      (incf free-index))

    ;; Strings get sorted then added with our custom routine.
    (let* ((strs        (ser-encoder-strings encoder))
           (strs-sorted (ser-time? (sort strs #'string<))))
      (multiple-value-bind (free strs-chopped)
        (ser-time? (ser-make-atom-map-for-strings strs-sorted free-index seen-str nil))
        (setf (ser-encoder-strings encoder) strs-chopped)
        (setf free-index free)))

    ;; Turn the hash table of symbols into an alist so that they're in the same
    ;; order now and when we encode.  This might not be necessary, but it's
    ;; probably very cheap in practice because there's only one entry per
    ;; package.
    (let ((al nil))
      (maphash (lambda (key val)
                 (push (cons (package-name key) val) al))
               (ser-encoder-symbol-ht encoder))
      (setf (ser-encoder-symbol-al encoder) al))

    (dolist (elem (ser-encoder-symbol-al encoder))
      (dolist (sym (cdr elem))
        ;; We don't have to check for T and NIL because we didn't accumulate
        ;; them into the symbol table.
        (setf (gethash sym seen-sym) free-index)
        (incf free-index)))

    ;; V2 change: explicitly assign nil and t indices 0 and 1
    (setf (gethash nil seen-sym) 0)
    (setf (gethash t seen-sym) 1)

    ;; Finally, update the encoder with the free index we've arrived at.
    (setf (ser-encoder-free-index encoder) free-index)))




; -----------------------------------------------------------------------------
;
;                      ENCODING AND DECODING CONSES
;
; -----------------------------------------------------------------------------

; After the atoms have been assigned their indices as above, we are going to
; write out a list of instructions for reassembling the conses in the object.
; We keep incrementing the free-index as we go so that the atoms and conses end
; up in a shared index-space.  Just as we smashed the seen-tables for the
; atoms, we also smash the seen-cons table to reuse its space for the indices.
;
; In earlier versions of serialize, we separated the act of generating
; instructions from writing them.  But now for greater efficiency we fuse the
; two operations so that we never need to record the instructions anywhere
; except in the stream.
;
; We call ser-encode-conses only after generating all of the atom maps,
; writing out all the atoms in the file, and writing the number of conses that
; we are about to build (which is available as the count of the seen-cons
; table.)

(defun ser-encode-conses
  (x          ; the object we are encoding, which we are recurring through
   encoder    ; the encoder's state (so we can look at all the tables)
   )
  "Returns X-INDEX"
  (declare (type ser-encoder encoder))
  (if (atom x)
      ;; Atoms already have their indices assigned, so there's nothing
      ;; to do but look them up.
      (cond ((symbolp x)
             (gethash x (ser-encoder-seen-sym encoder)))
            ((stringp x)
             (gethash x (ser-encoder-seen-str encoder)))
            (t
             (gethash x (ser-encoder-seen-eql encoder))))

    (let* ((seen-cons (ser-encoder-seen-cons encoder))
           (idx       (gethash x seen-cons)))

      ;; At this point you might expect to see something like, "(if idx ...)".
      ;; But since we are reusing the seen-cons table, every cons that does not
      ;; already have its index assign is bound to T, not unbound.  To see if
      ;; an index has been assigned, then, we have to check if it is a number.
      ;; Since all indices are fixnums, I check whether it's a fixnum, which is
      ;; very fast (just looking at type bits), at least on CCL.
      (if (typep idx 'fixnum)
          idx
        (let* ((car-index (ser-encode-conses (car x) encoder))
               (cdr-index (ser-encode-conses (cdr x) encoder))

               ;; At this point, we've assigned indices to the car and cdr.
               ;; We've also written out all of the instructions needed to
               ;; generate them in the stream.  We can now assign an index to X
               ;; and write the instruction for rebuilding it:
               (free-index (ser-encoder-free-index encoder))
               (stream     (ser-encoder-stream encoder))

               ;; V2 change: we now write (car-index << 1) | (if honsp 1 0)
               ;; instead of just car-index.  Note that these fixnum
               ;; declarations are justified by the checking we do in
               ;; ser-encode-to-stream
               (v2-car-index
                (if (hl-hspace-honsp-wrapper x)
                    (the fixnum (logior (the fixnum (ash car-index 1)) 1))
                  (the fixnum (ash car-index 1)))))

          (setf (gethash x seen-cons) free-index)
          (ser-encode-nat v2-car-index stream)
          (ser-encode-nat cdr-index stream)
          (setf (ser-encoder-free-index encoder) (the fixnum (+ 1 free-index)))
          free-index)))))


(defmacro ser-decode-loop (version hons-mode)

  `(loop until (= (the fixnum stop) free) do

         (let ((first-index (ser-decode-nat stream)))
           (unless (typep first-index 'fixnum)
             (error "Consing instruction has non-fixnum first-index."))

           (let ((car-index ,(if (eq version :v1)
                                 'first-index
                               '(the fixnum (ash (the fixnum first-index) -1))))

                 (honsp     ,(cond ((eq hons-mode :always)
                                    't)
                                   ((and (eq hons-mode :smart)
                                         (eq version :v2))
                                    '(logbitp 0 (the fixnum first-index)))
                                   (t
                                    nil)))

                 (cdr-index (ser-decode-nat stream)))

              ;; Performance testing suggests these bounds checks are
              ;; almost free.
              (unless (and (typep cdr-index 'fixnum)
                           (< (the fixnum car-index) free)
                           (< (the fixnum cdr-index) free))
                (error "Consing instruction has index out of bounds."))
              (let ((car-obj (svref arr (the fixnum car-index)))
                    (cdr-obj (svref arr (the fixnum cdr-index))))
                (setf (svref arr free)
                      (if honsp
                          (hons car-obj cdr-obj)
                        (cons car-obj cdr-obj)))
                (incf free))))))


(defun ser-decode-and-load-conses (hons-mode decoder stream)

  ;; The valid hons modes are:
  ;;   :always  - always hons regardless of hons bits
  ;;   :never   - never hons regardless of hons bits
  ;;   :smart   - hons only when hons bits are set (v2 only)
  ;;              smart does no honsing for v1 files

  (declare (type ser-decoder decoder))
  (let* ((len          (ser-decode-nat stream))
         (arr          (ser-decoder-array decoder))
         (free         (ser-decoder-free decoder))
         (version      (ser-decoder-version decoder))
         (stop         (+ free len)))
    (declare (fixnum free))
    (ser-print? "; Decoding ~a consing instructions.~%" len)

    (unless (<= stop (length arr))
      ;; Like our other decoders, we only need a single bounds check to make
      ;; sure we won't overflow the array as we decode the conses.
      (error "Invalid serialized object, too many conses."))

    ;; This is a gross hack so that we have five different loops, optimized for
    ;; the different cases of hons-mode and file version.
    (if (eq version :v1)
        (if (eq hons-mode :always)
            (ser-decode-loop :v1 :always)
          (ser-decode-loop :v1 :never))
      (cond ((eq hons-mode :always)
             (ser-decode-loop :v2 :always))
            ((eq hons-mode :never)
             (ser-decode-loop :v2 :never))
            (t
             (ser-decode-loop :v2 :smart))))

    (setf (ser-decoder-free decoder) stop)))




(defun ser-encode-atoms (encoder)
  (declare (type ser-encoder encoder))

; It's sort of silly for this to be its own function, but it makes a convenient
; target for timing.

  (let ((stream (ser-encoder-stream encoder)))
    (ser-encode-nats      (ser-encoder-naturals encoder)  stream)
    (ser-encode-rats      (ser-encoder-rationals encoder) stream)
    (ser-encode-complexes (ser-encoder-complexes encoder) stream)
    (ser-encode-chars     (ser-encoder-chars encoder)     stream)
    (ser-encode-strs      (ser-encoder-strings encoder)   stream)
    (ser-encode-packages  (ser-encoder-symbol-al encoder) stream)))


(defun ser-encode-to-stream (obj stream)

; Serialize the OBJ and write it to the stream.  This writes "everything from
; magic number to magic number."  Note that it does NOT include the #Z prefix,
; which is needed if you're going to read the object back in.

  (let ((encoder (make-ser-encoder :stream stream))
        starting-free-index-for-conses
        total-number-of-objects
        max-index
        nconses)
    (declare (dynamic-extent encoder))

    ;; Make sure the hons space is initialized
    (hl-maybe-initialize-default-hs-wrapper)
    (ser-time? (ser-gather-atoms obj encoder))

    (setq nconses (hash-table-count (ser-encoder-seen-cons encoder)))

    (unless (typep (ash (+ 2 ;; to account for T and NIL
                           (hash-table-count (ser-encoder-seen-sym encoder))
                           (hash-table-count (ser-encoder-seen-eql encoder))
                           (hash-table-count (ser-encoder-seen-str encoder))
                           nconses)
                        1)
                   'fixnum)
      ;; This check ensures that all indexes will be fixnums.  The sum above
      ;; may actually exceed the actual maximum index we will have, because
      ;; EQUAL-but-not-EQ strings will be removed.  But it is at least as large
      ;; as the maximum index, so if it is a fixnum then all indexes are
      ;; fixnums.  In V1 we just checked if the sum was a fixnum.  In V2 we
      ;; need to shift it since indices get shifted in the file.
      (error "Maximum index exceeded."))

    (ser-time? (ser-make-atom-map encoder))
    (setq starting-free-index-for-conses (ser-encoder-free-index encoder))

    (ser-encode-magic stream)

    (setq total-number-of-objects
          (the fixnum (+ starting-free-index-for-conses nconses)))

    (ser-encode-nat (cond ((eq obj nil)
                           0)
                          (t
                           (- total-number-of-objects 1)))
                    stream)

    (ser-time? (ser-encode-atoms encoder))
    (ser-encode-nat nconses stream)
    (setq max-index (ser-time? (ser-encode-conses obj encoder)))

    (unless (and (equal (ser-encoder-free-index encoder)
                        total-number-of-objects)
                 (or (equal max-index (- (ser-encoder-free-index encoder) 1))
                     ;; in v2, max-index can be 0 and 1 also, for nil or t.
                     ;; if it happens to be t, then it's still going to be one
                     ;; less than the max free index.
                     (equal max-index 0)))
      (error "Sanity check failed in ser-encode-to-stream!~% ~
                - final-free-index is ~a~% ~
                - total-number-of-objects is ~a~% ~
                - max-index is ~a~%"
             (ser-encoder-free-index encoder)
             total-number-of-objects
             max-index))

    (ser-encode-magic stream)))




(defun ser-decode-and-load-atoms (check-packagesp decoder stream)
  (declare (type ser-decoder decoder))
  (ser-decode-and-load-nats decoder stream)
  (ser-decode-and-load-rats decoder stream)
  (ser-decode-and-load-complexes decoder stream)
  (ser-decode-and-load-chars decoder stream)
  (ser-decode-and-load-strs decoder stream)
  (ser-decode-and-load-packages check-packagesp decoder stream))


(defun ser-decode-from-stream (check-packagesp hons-mode stream)

; Read a serialized object from the stream.  This reads "everything from magic
; number to magic number."  Note that it does NOT expect there to be a #Z
; prefix.

  (let* ((version  (ser-decode-magic stream))
         (size/idx (ser-decode-nat stream))
         (arr-size (if (eq version :v2)
                       (cond ((eq size/idx 0)
                              2)
                             (t
                              (+ size/idx 1)))
                     size/idx))
         (final-obj (if (eq version :v2)
                        size/idx
                      (- arr-size 1))))

    (unless (typep arr-size 'fixnum)
      (error "Serialized object is too large."))

    (let* ((arr     (make-array arr-size))
           (decoder (make-ser-decoder :array arr
                                      :free 0
                                      :version version)))
      (declare (dynamic-extent arr decoder)
               (type ser-decoder decoder))

      (when (eq version :v2)
        (setf (aref arr 0) nil)
        (setf (aref arr 1) t)
        (setf (ser-decoder-free decoder) 2))

      (ser-print? "; Decoding serialized object of size ~a.~%" arr-size)
      (ser-time? (ser-decode-and-load-atoms check-packagesp decoder stream))
      (ser-time? (ser-decode-and-load-conses hons-mode decoder stream))

      (unless (eq (ser-decode-magic stream) version)
        (error "Invalid serialized object, magic number mismatch."))

      (unless (= (ser-decoder-free decoder) arr-size)
        (error "Invalid serialized object.~% ~
                 - Decode-free is ~a~%
                 - Arr-size is ~a."
               (ser-decoder-free decoder) arr-size))

      (svref arr final-obj))))




; -----------------------------------------------------------------------------
;
;                           ACL2 INTEGRATION
;
; -----------------------------------------------------------------------------

(defun ser-cons-reader-macro (stream subchar arg)
  (declare (ignorable subchar arg))
  ;; This is the reader macro for #z.  When it is called the #z part has
  ;; already been read, so we just want to read the serialized object.
  (ser-decode-from-stream nil :never stream))

(defun ser-hons-reader-macro (stream subchar arg)
  (declare (ignorable subchar arg))
  ;; This is the reader macro for #Z.  When it is called the #Z part has
  ;; already been read, so we just want to read the serialized object.
  (ser-decode-from-stream nil :smart stream))


