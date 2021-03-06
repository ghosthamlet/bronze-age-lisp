;;;
;;; ports.k
;;;
;;; High-level port features.
;;;

($define-private-lambda! ignore-errors-guard (x d)
  (d))

($define-ground-lambda! close-port-ignore-errors (p)
  (guard-dynamic-extent
    ()
    ($lambda () (close-port p))
    (list (list error-continuation ignore-errors-guard)))
  #inert)

($define-ground-lambda! call-with-port (port proc)
  ($let*
    ((result
      (guard-dynamic-extent
        ()
        ($lambda () (proc port))
        (list (list error-continuation
                    ($lambda (x d)
                      (close-port-ignore-errors port)
                      x))))))
    (close-port port)
    result))

($define-ground-lambda! call-with-input-file (file proc)
  (call-with-port (open-input-file file) proc))

($define-ground-lambda! call-with-output-file (file proc)
  (call-with-port (open-output-file file) proc))

($define-ground-lambda! call-with-binary-input-file (file proc)
  (call-with-port (open-binary-input-file file) proc))

($define-ground-lambda! call-with-binary-output-file (file proc)
  (call-with-port (open-binary-output-file file) proc))

;;
;; management of dynamic port variables
;;

($define-ground-lambda! get-current-input-port () stdin)
($define-ground-lambda! get-current-output-port () stdout)
($define-ground-lambda! get-current-error-port () stderr)

($define-private-vau! $with-dynamic-port (symbol new proc) denv
  ($define! new (eval new denv))
  ($define! proc (eval proc denv))
  ($define! old (eval symbol private-environment))
  (set! private-environment symbol new)
  ($define! result
    (guard-dynamic-extent
      (list
        (list root-continuation
              ($lambda (x #ignore)
                (set! private-environment symbol new)
                x)))
        proc
        (list
          (list root-continuation
                ($lambda (x #ignore)
                  (set! private-environment symbol old)
                   x)))))
  (set! private-environment symbol old)
  result)

($define-ground-lambda! with-input-from-port (port proc)
  ($with-dynamic-port stdin port proc))

($define-ground-lambda! with-output-to-port (port proc)
  ($with-dynamic-port stdout port proc))

($define-ground-lambda! with-input-from-file (file proc)
  (call-with-input-file file
    ($lambda (port) (with-input-from-port port proc))))

($define-ground-lambda! with-output-to-file (file proc)
  (call-with-output-file file
    ($lambda (port) (with-output-to-port port proc))))

;; Name it with-input-from-binary-file or with-binary-input-from-file?
;; I don't know, but the former won Google Fight.

($define-ground-lambda! with-input-from-binary-file (file proc)
  (call-with-binary-input-file file
    ($lambda (port) (with-input-from-port port proc))))

($define-ground-lambda! with-output-to-binary-file (file proc)
  (call-with-binary-output-file file
    ($lambda (port) (with-output-to-port port proc))))

($define-ground-lambda! with-input-from-string (s proc)
  (with-input-from-port (open-input-string s) proc))

($define-ground-lambda! with-output-to-string (proc)
  ($let* ((port (open-output-string)))
    (with-output-to-port port proc)
    (get-output-string port)))

($define-ground-lambda! with-output-to-bytevector (proc)
  ($let* ((port (open-output-bytevector)))
    (with-output-to-port port proc)
    (get-output-bytevector port)))

;; optional argument checking

($define-private-vau! $optional-port-argument (rest ok? default name) denv
  ($define! rest (eval rest denv))
  ($cond
    ((null? rest)
      (eval default denv))
    (($and? (pair? rest) (null? (cdr rest)))
      ($if (eval (list ok? (car rest)) denv)
        (car rest)
        (eval (list $error1 name "Invalid port argument." (car rest))
              denv)))
    (#t
      (eval (list $error1 name "Invalid argument structure." rest)
            denv))))

;; get-module (definition adapted from KR)

($define-ground-lambda! get-module (filename . opt)
  ($let* ((env (make-kernel-standard-environment)))
    ($when (pair? opt)
      ($set! env module-parameters (car opt)))
    (eval (list load filename) env)
    env))

;; klisp-compatible (find-required-filename STRING)
;;
($bind-private! require-path-components #inert)

($define-ground-lambda! find-required-filename (x)
  (init-rq)
  ($let (((path . port)
         (find-and-open-rq x require-path-components ())))
    (close-port port)
    path))

($defun-privates!
  (find-and-open-rq (key cs fs)
    ($cond
      ((pair? cs)
        ($define! p
          (apply string-append (list* (caar cs) key (cdar cs))))
        ($define! q
          (guard-dynamic-extent
            ()
            ($lambda () (open-input-file p))
            (list (list error-continuation ignore-errors-guard))))
        ($if (port? q)
          (cons p q)
          (find-and-open-rq key (cdr cs) (cons p fs))))
      (#t
        (error "Required file not found."
          (list #:key key)
          (list* #:tried (reverse fs))))))
  (init-rq ()
    ($when (inert? require-path-components)
      ($let
        ((spec ($cond
                 ((defined-environment-variable? "KLISP_PATH")
                   (get-environment-variable "KLISP_PATH"))
                 (#t
                   "./?;./?.k"))))
        ($set! private-environment require-path-components
          (map ($lambda (v) (split-require-string v #\?))
            (split-require-string spec #\;))))))
  (split-require-string (s d)
    ($letrec
      ((aux
        ($lambda (p d q)
          ($let1 c (read-char p)
            ($cond
             ((eq? c d)
               (cons (get-output-string q)
                     (aux p d (open-output-string))))
             ((eof-object? c)
               (list (get-output-string q)))
             (#t
               (write-char c q)
               (aux p d q)))))))
      (aux (open-input-string s) d (open-output-string)))))

;; klisp-compatible (register-requirement ...)
;;
($bind-private! require-table ())

($define-ground-lambda! registered-requirement? (key)
  ($unless (string? key) (error "Invalid require-key." key))
  (member? key require-table))

($define-ground-lambda! register-requirement! (key)
  ($unless (string? key) (error "Invalid require-key." key))
  ($if (member? key require-table)
    (error "Requirement already registered." key)
    ($set! private-environment require-table
      (cons key require-table))))

($define-ground-lambda! unregister-requirement! (key)
  ($unless (string? key) (error "Invalid require-key." key))
  ($if (member? key require-table)
    ($set! private-environment require-table
      (filter ($lambda (elt) (not? (equal? key elt)))
        require-table))
    (error "Requirement not registered." key)))

;; klisp-compatible (require ...)
;;
($define-ground-lambda! require (key)
  ($unless (registered-requirement? key)
    (init-rq)
    ($let*
      (((path . port)
         (find-and-open-rq key require-path-components ()))
       (forms
         (guard-dynamic-extent
          ()
          ($lambda () (read-all port ()))
          (list (list root-continuation
                      ($lambda (obj . #ignore)
                        (close-port port)
                        (error "Error while loading required file." path obj)))))))
      (close-port port)
      (register-requirement! key)  ; register now to prevent looping
      (guard-dynamic-extent
        ()
        ($lambda ()
          (eval
            (cons $sequence (copy-es-immutable forms))
            (make-kernel-standard-environment)))
        (list
          (list error-continuation
                ($lambda (obj . #ignore)
                  ($when (registered-requirement? key) ; maybe it was unregistered during evaluation
                    (unregister-requirement! key))
                  (error-rq path obj))))))))

($define-private-lambda! error-rq (path e)
  ($let ((msg "Error while executing required file."))
    ($if
      ($and? (error-object? e)
             (=? (length (error-object-irritants e)) 2)
             (finite-list? (car (error-object-irritants e)))
             (eq? (error-object-message e) msg))
      (error msg
        (cons path (car (error-object-irritants e)))
        (cadr (error-object-irritants e)))
      (error msg
        (list path) e))))

;; read-line
;;
($define-ground-lambda! read-line args
  ($define! p ($optional-port-argument args textual-input-port? stdin read-line))
  #1=($define! c (read-char p))
  ($cond
    (#2=(eof-object? c) c)
    (#3=(eq? c #\newline) "")
    (#t
      ($define! q (open-output-string))
      #4=($sequence
           (write-char c q)
           #1#
           ($if ($or? #2# #3#)
              (get-output-string q)
              #4#)))))

;; terminal attributes
;;
($bind-ground! tcgetattr
  (make-bounded-applicative
    (list 1 1) (list "app_tcgetattr.A1") ()))
($bind-ground! tcsetattr
  (make-bounded-applicative
    (list 2 2) (list "app_tcsetattr.A2") ()))
($bind-ground! tc-cbreak-noecho
  (make-bounded-applicative
    (list 1 1) (list "app_tc_cbreak_noecho.A1") ()))

($define-ground-lambda! with-noncanonical-input (f)
  ($define! p stdin)
  ($define! old (tcgetattr p))
  ($define! new (tc-cbreak-noecho old))
  (tcsetattr p new)
  ($define! r
    (guard-dynamic-extent
      (list (list root-continuation
                  ($lambda (obj . #ignore)
                    (tcsetattr p new)
                    obj)))
      ($lambda () (apply f ()))
      (list (list root-continuation
                  ($lambda (obj . #ignore)
                    (tcsetattr p old)
                    obj)))))
  (tcsetattr p old)
  r)

;; char-ready?
;;
($bind-ground! char-ready?
  (make-bounded-applicative
    (list 0 1)
    (list "app_char_readyP.A0" "app_char_readyP.A1")
    ()))

($bind-ground! u8-ready?
  (make-bounded-applicative
    (list 0 1)
    (list "app_char_readyP.A0" "app_char_readyP.A1")
    ()))

;; close-input-file and close-output-file
;;
($define-ground-lambda! close-input-file (p)
  ($if ($and? (port? p) (file-port? p) (input-port? p))
    (close-port p)
    ($error1 close-input-file "Invalid argument." p)))

($define-ground-lambda! close-output-file (p)
  ($if ($and? (port? p) (file-port? p) (output-port? p))
    (close-port p)
    ($error1 close-output-file "Invalid argument." p)))
