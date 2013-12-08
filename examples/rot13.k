;;;
;;; rot13.k
;;;
;;; usage: bronze.bin rot13.k <INPUT.k >OUTPUT.k
;;;   or   klisp rot13.k <INPUT.k >OUTPUT.k
;;;
;;; Encrypts each symbol and string in INPUT.k with ROT13. Writes the
;;; obfuscated program to the output file, together with a preamble
;;; which decrypts and executes it when (load ...)'ed.
;;;
;;; This program shows how to use first-class operatives (FEXPRs)
;;; to capture and manipulate part of its source code, see
;;; $provide-with-source! below. Also, this program demonstrates
;;; use of $let-safe.
;;;

;;
;; Define ($quote ...) for the sake of Klisp compatibility.
;;
($define! $quote (unwrap list*))

;;
;; First, we implement the ROT13 transformation. We need the same
;; implementation also for decrypting. We keep the source code of
;; the implementation around and later write it to the output file.
;;
;; ($provide-with-source SOURCE-VAR SYMBOLS . BODY)
;;
;; Executes ($provide SYMBOLS . BODY) and captures the source of the
;; form, binding SOURCE-VAR to (SYMBOLS . BODY)
;; 
;;
($define! $provide-with-source!
  ($vau (source-variable . symbols-body) denv
    (eval (list* $provide! symbols-body) denv)
    (eval (list $define! source-variable (list $quote symbols-body)) denv)))

($provide-with-source! rot13-source (rot13 map-atoms)

  ;;
  ;; (rot13 CHAR) => CHAR
  ;;
  ;; Encrypt arbitrary object.
  ;;
  ($define! rot13
    ($lambda (obj)
      (map-atoms
        ($lambda (a)
          ($cond
            ((string? a)
              (string-map char-rot13 a))
            ((symbol? a)
              (string->symbol (string-map char-rot13 (symbol->string a))))
            (#t
              a)))
        obj)))

  ;;
  ;; (char-rot13 CHAR) => CHAR
  ;;
  ;; Encrypt single character.
  ;;
  ($define! char-rot13
    ($lambda (c)
      ($cond
        ((char<=? #\a c #\z)
          (integer->char (+ 97 (mod (- (char->integer c) 110) 26))))
        ((char<=? #\A c #\Z)
          (integer->char (+ 65 (mod (- (char->integer c) 78) 26))))
        (#t
          c))))

  ;;
  ;; (map-atoms F OBJECT) => OBJECT
  ;;
  ;; Copies OBJECT, changing each non-pair object X into (F X). Works
  ;; also for cyclic structures.
  ;;
  ($define! map-atoms
    ($lambda (f start)
      ($letrec
        ((env     (get-current-environment))
         (visited ())
         (visit!  ($lambda (x store! place)
                    ($if (not? (pair? x))
                      (store! place (f x))
                      ($let ((z (assoc x visited)))
                        ($if (pair? z)
                          (store! place (cdr z))
                          ($let ((v (cons () ())))
                            (store! place v)
                            ($set! env visited (cons (cons x v) visited))
                            (visit! (car x) set-car! v)
                            (visit! (cdr x) set-cdr! v)))))))
         (clone  (list ())))
        (visit! start set-car! clone)
        (car clone)))))

;;
;; ($simple-quasiquote SYMBOLS OBJECT) => OBJECT
;;
;; Copies OBJECT, replacing each symbol listed in SYMBOLS with
;; its value in the dynamic environment. Simple variant of lisp/scheme
;; quasiquote:
;;
;;  `(a b ,c d) === ($simple-quasiquote (c) (a b c d))
;;
($define! $simple-quasiquote
  ($vau (antiquoted quoted) denv
    (map-atoms
      ($lambda (x) ($if (member? x antiquoted) (eval x denv) x))
      quoted)))

;;
;; (self-decrypting-script PROGRAM)
;;
;; Returns a form which contains encrypted PROGRAM. The results should
;; be evaluated in an environment where $let-safe is bound to its
;; standard value. The evaluation will be equivalent to evaluation of
;; the original PROGRAM.
;;
($define! self-decrypting-script
  ($lambda (plaintext-program)
    ($define! encrypted-program (rot13 plaintext-program))
    ($simple-quasiquote (rot13-source encrypted-program)
      (($let-safe ()
        ($vau () env
          ($provide! . rot13-source)
          (eval ((unwrap rot13) encrypted-program) env)))))))

;;
;; (read-list)
;;
;; Read all objects from the current input port until EOF.
;;
($define! read-list
  ($lambda ()
    ($define! form (read))
    ($if (eof-object? form)
      ()
      (cons form (read-list)))))

;;
;; Uff.
;;
(write (self-decrypting-script (cons ($quote $sequence) (read-list))))
(newline)
