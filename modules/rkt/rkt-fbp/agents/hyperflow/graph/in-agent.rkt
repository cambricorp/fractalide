#lang racket

(require fractalide/modules/rkt/rkt-fbp/agent
         fractalide/modules/rkt/rkt-fbp/graph)

(define-agent
  #:input '("in") ; in array port
  #:output '("out") ; out port
   (define msg (recv (input "in")))
   (define path (string-split msg "modules/rkt/rkt-fbp/"))
   (define o (g-agent "" (cadr path)))
   (send (output "out") o))
