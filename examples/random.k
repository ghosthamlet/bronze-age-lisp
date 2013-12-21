;;;
;;; random.k
;;;
;;; Pseudo-random number generator, with interface inspired by SRFI-27.
;;;
;;;
;;; ``Random source'' encapsulates state of a PRNG.
;;;
;;;   (make-random-source) => RANDOM-SOURCE
;;;   (random-source? . OBJECTs)
;;;
;;; The state can be extracted and reinstalled into the random source.
;;;
;;;   (random-source-state-ref RANDOM-SOURCE) => OBJECT
;;;   (random-source-state-set! RANDOM-SOURCE OBJECT) => #inert
;;;
;;; The state can be initialized from /dev/urandom.
;;;
;;;   (random-source-randomize! RANDOM-SOURCE)
;;;
;;; Applicatives which generate random integers in the range
;;; 0...N-1 or 0...2^p-1 can be constructed.
;;;
;;;   (random-source-make-integers RANDOM-SOURCE) => ifunc
;;;   (random-source-make-bits RANDOM-SOURCE) => bfunc
;;;
;;;   (ifunc N) => integer in the range 0...N-1
;;;   (bfunc P) => integer in the range 0...2^P-1
;;;
;;; There is also a default random source with simple interface
;;;
;;;   default-random-source
;;;   (random-integer N) => integer
;;;   (random-bits P) => integer
;;;
;;; In addition to the SRFI-27 interface, randomized operatives
;;; are defined:
;;;
;;;   (list-ref-random LIST)
;;;
;;;     Returns a randomly chosen element of a non-empty LIST.
;;;
;;;   ($random-choice EXPR1 EXPR2 ... EXPRn)
;;;
;;;     Picks one of the expressions at random and evaluates it.
;;;

($provide! (make-random-source random-source?
            random-source-state-ref random-source-state-set!
            random-source-randomize!
            random-source-make-integers random-source-make-bits)

  ;; The PRNG is the "KISS" algorithm by George Marsaglia. This PRNG
  ;; generates one 32-bit unsigned integer a time. Its state consists
  ;; of four 32-bit unsigned integers named x, y, z, c.
  ;;
  ;; The random source objects is are encapsulated lists
  ;;
  ;;   (ENV U32)
  ;;
  ;; where ENV is an environment with the symbols x, y, z and c
  ;; bound, and U32 is an applicative which returns the next 32-bit
  ;; random sample and updates ENV.
  ;;

  ($define! (encapsulate random-source? decapsulate)
    (make-encapsulation-type))

  ($define! initial-state
    ($quote* (x 123456789)
             (y 362436000)
             (z 521288629)
             (c 7654321)
             (buffer 0)
             (buffer-bits 0)))

  ($define! state-variables (map car initial-state))

  ($define! random-source-state-ref
    ($lambda (s)
      (eval (cons list state-variables) (car (decapsulate s)))))

  ($define! random-source-state-set!
    ($lambda (s new-state)
      (set! (car (decapsulate s)) state-variables new-state)))

  ;; KISS implementation

  ($define! mask32 (- (arithmetic-shift 1 32) 1))

  ($define! a 698769069)

  ($define! $set32!
    ($vau (var expr) denv
      (set! state var (bitwise-and mask32 (eval expr denv)))))

  ($define! make-random-source
    ($lambda ()
      ($let*
        ((state   (apply (wrap $bindings->environment) initial-state))
         ($set32! ($vau (var expr) denv
                    (set! state var
                      (bitwise-and mask32 (eval expr denv)))))
         (u32 ($remote-eval
                ($lambda ()
                  ($set32! x (+ (* 69069 x) 12345))
                  ($set32! y (bitwise-xor y (arithmetic-shift y 13)))
                  ($set32! y (bitwise-xor y (arithmetic-shift y -17)))
                  ($set32! y (bitwise-xor y (arithmetic-shift y 5)))
                  ($let1 t (+ (* a z) c)
                    ($set32! c (arithmetic-shift t -32))
                    ($set32! z t))
                  (bitwise-and mask32 (+ x y z)))
                 (make-environment state (get-current-environment)))))
        (encapsulate (list state u32)))))

  ;; Derived operations. The variables buffer and buffer-bits
  ;; are stored in the state environment.

  ($define! random-source-make-bits
    ($lambda (s)
      ($define! (state random-u32) (decapsulate s))
      ($define! gen
        ($remote-eval
          ($lambda (n)
            ($cond
              ((<? buffer-bits n)
                ($set! state buffer (bitwise-ior (arithmetic-shift buffer 32)
                                                 (random-u32)))
                ($set! state buffer-bits (+ 32 buffer-bits))
                (gen n))
              (#t
                ($define! r (bitwise-and buffer (- (arithmetic-shift 1 n) 1)))
                ($set! state buffer-bits (- buffer-bits n))
                ($set! state buffer (arithmetic-shift buffer (negate n)))
                r)))
           (make-environment state (get-current-environment))))
        gen))

  ($define! random-source-make-integers
    ($lambda (s)
      ($define! random-bits (random-source-make-bits s))
      ($lambda (n)
        ($unless (positive? n)
          (error "((random-source-make-integers ...) ...)" n))
        ($let-repeat-until r (random-bits (integer-length n)) (<? r n)))))

  ($define! try-until
    ($lambda (stop? try)
      ($define! loop
        ($lambda ()
          ($define! result (try))
          ($if (stop? result) result (loop))))
      (loop)))

  ($define! $let-repeat-until
    ($vau (lhs try stop) denv
      (try-until (eval (list $lambda (list lhs) stop) denv)
                 (eval (list $lambda () try) denv))))

  ;; randomization

  ($define! read-u32
    ($lambda ()
      (apply bitwise-ior
             (list-tabulate 4
               ($lambda (k) (arithmetic-shift (read-u8) (* 8 k)))))))

  ($define! read-u32-nz
    ($lambda () (try-until positive? read-u32)))

  ($define! random-source-randomize!
    ($lambda (s)
      (with-input-from-binary-file "/dev/urandom"
        ($lambda ()
          (random-source-state-set! s
            (list (read-u32) (read-u32-nz) (read-u32) 7654321)))))))

;;
;; the simple interface

($define! default-random-source (make-random-source))
($define! random-integer (random-source-make-integers default-random-source))
($define! random-bits (random-source-make-bits default-random-source))

;;
;; randomized operatives
;;

($define! list-ref-random
  ($lambda (xs)
    (list-ref xs (random-integer (car (get-list-metrics xs))))))

($define! $random-choice
  ($vau exprs denv
    (eval (list-ref-random exprs) denv)))
