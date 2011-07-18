;;; -*- Mode: Lisp; -*-

;; ASDF Manual: http://constantly.at/lisp/asdf/

(defpackage :ioforms-asd)

(in-package :ioforms-asd)

(asdf:defsystem ioforms
  :name "ioforms"
  :version "0.91"
  :maintainer "David T O'Toole <dto1138@gmail.com>"
  :author "David T O'Toole <dto1138@gmail.com>"
  :license "General Public License (GPL) Version 3"
  :description "IOFORMS is a visual programming language for Common Lisp."
  :serial t
  :depends-on (:lispbuilder-sdl 
	       :lispbuilder-sdl-image 
	       :lispbuilder-sdl-gfx
	       :lispbuilder-sdl-ttf
	       :lispbuilder-sdl-mixer
	       :uuid
	       :quicklisp
	       :buildapp
	       :cl-fad
	       :cl-opengl)
  :components ((:file "ioforms")
	       (:file "rgb" :depends-on ("ioforms"))
	       (:file "keys" :depends-on ("ioforms"))
	       (:file "math" :depends-on ("ioforms"))
	       (:file "logic" :depends-on ("ioforms"))
	       (:file "prototypes" :depends-on ("ioforms"))
	       (:file "console" :depends-on ("prototypes"))
	       (:file "blocks" :depends-on ("console"))
	       (:file "widgets" :depends-on ("blocks"))
	       (:file "trees" :depends-on ("blocks"))
	       (:file "terminal" :depends-on ("blocks"))
	       (:file "system" :depends-on ("blocks"))
	       (:file "things" :depends-on ("blocks"))
	       (:file "worlds" :depends-on ("things"))
	       (:file "shell" :depends-on ("trees" "terminal" "system"))
	       (:file "oop" :depends-on ("trees" "terminal" "widgets" "system"))
	       (:file "library" :depends-on ("worlds" "shell"))))
;;	       (:file "path")
	       
	       
