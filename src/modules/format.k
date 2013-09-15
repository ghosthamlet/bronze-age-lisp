;;;
;;; format.k
;;;
;;; Simple CL-style format string facility.
;;;
;;; (format [DEST] FORMAT-STRING . ARGS)
;;;
;;; Called as
;;;
;;;    (format PORT STRING . ARGS)    print to PORT
;;;    (format #t STRING . ARGS)      print to current output port
;;;    (format #f STRING . ARGS)      return a string
;;;    (format STRING . ARGS)         return a string (compatible with SRFI-28).
;;;
;;; Only small subset of formatting directives is implemented:
;;;
;;;  ~a              print an object like (display ...)
;;;  ~s              print an object like (write-simple ...)
;;;  ~w              print an object like (write ...)
;;;  ~c              print a character, unescaped
;;;
;;;  ~b ~d ~o ~x     print integer in base 10, 2, 8, 16
;;;
;;;  ~~              print a tilde
;;;  ~%              print a newline
;;;  ~<whitespace>   skip whitespace in format string
;;;
;;;

($bind-private! format-directives
  ($quote*
    (#\a       . (display (consume)))
    (#\b       . (print-integer (consume) 2 (get-current-output-port)))
    (#\c       . (write-char (consume)))
    (#\d       . (print-integer (consume) 10 (get-current-output-port)))
    (#\o       . (print-integer (consume) 8 (get-current-output-port)))
    (#\s       . (write-simple (consume)))
    (#\w       . (write (consume)))
    (#\x       . (print-integer (consume) 16 (get-current-output-port)))
    (#\~       . (write-char #\~))
    (#\%       . (write-char #\newline))
    (#\return  . (format-skip 1))
    (#\newline . (format-skip 0))
    (#\space   . (format-skip 1))
    (#\tab     . (format-skip 1))))

($define-private-lambda! format-skip (n)
  ($let1 c (peek-char)
    ($cond
      ((eq? c #\newline)
        ($when (positive? n)
          (read-char)
          (format-skip (- n 1))))
      ((char-whitespace? c)
        (read-char)
        (format-skip n))
      (#t
        #inert))))

($define-ground-lambda! format args
  ($define! to-port
    ($lambda (p)
      ($lambda (f) (with-output-to-port p f))))
  ($define! (dest fmt . items)
    ($match args
      ((h . t)
        ($cond
          ((string? h) (list* with-output-to-string h t))
          ((eq? h #f)  (list* with-output-to-string t))
          ((eq? h #t)  (cons (to-port (get-current-output-port)) t))
          ((port? h)   (cons (to-port h) t))
          (#t          (error "Invalid argument." h))))
      (args
        (error "Invalid argument structure." (cons format args)))))
  ($define! state
    (cons items items))
  ($define! consume
    ($lambda ()
      ($let1 x (car state)
        ($unless (pair? x)
          (error "Format ran out of arguments." fmt items))
        (set-car! state (cdr x))
        (car x))))
  ($define! loop
    ($lambda ()
      . #1=(($define! c (read-char))
            ($cond
              ((eq? c #\~)
                ($define! d (read-char))
                ($match (assq d format-directives)
                  ((#ignore . rest) (eval rest (get-current-environment)))
                  (() (error "Unknown format directive." d fmt)))
                . #1#)
              ((char? c)
                (write-char c)
                . #1#)
              (#t
                (flush-output-port))))))
  (with-input-from-string fmt
    ($lambda () (dest loop))))
