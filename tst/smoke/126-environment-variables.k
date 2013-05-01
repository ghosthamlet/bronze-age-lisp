;; test (get-environment-variable ...)
(list
  (get-environment-variable "HOME")
  (get-environment-variable "SHELL")
  (defined-environment-variable? "PATH")
  (defined-environment-variable? "fsfjsadoi"))
