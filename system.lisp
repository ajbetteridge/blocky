;;; system.lisp --- one block to rule them all

;; Copyright (C) 2010, 2011  David O'Toole

;; Author: David O'Toole ^dto@gnu.org
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see ^http://www.gnu.org/licenses/.

;;; Commentary:

;;; Code:

(in-package :ioforms)

(defvar *system* nil)

(defparameter *system-menu*
  '((:label "Project"
     :inputs
     ((:label "Create a new project" :action :create-project)
      (:label "Open an existing project" :action :open-existing-project)
;	      :schema ((:name . :string)))
      (:label "Save current changes" :action :save-changes)
      (:label "Show current changes without saving" :action :show-changes)
      (:label "Export as archive" :action :export-archive)
      (:label "Export as application" :action :export-application)
      (:label "Publish to web" :action :publish-web)
      (:label "Publish to community cloud" :action :publish-community)
      (:label "Publish to FTP" :action :publish-ftp)
      (:label "Edit preferences" :action :edit-preferences)
      (:label "Quit IOFORMS" :action :quit-ioforms)))
    (:label "Edit"
     :inputs
     ((:label "Cut" :action :cut)
      (:label "Copy" :action :copy)
      (:label "Paste" :action :paste)
      (:label "Paste as new workspace" :action :paste-as-new-workspace)
      (:label "Select all" :action :select-all)
      (:label "Clear selection" :action :clear-selection)))
    (:label "Resources"
     :inputs
     ((:label "Import new resource" :action :import-resources)
      (:label "Edit resource" :action :edit-resource)
      (:label "Search resources" :action :search-resources)
      (:label "Export resource(s)" :action :export-resources)
      (:label "Browse resources"
       :inputs
       ((:label "Browse objects" :action :browse-objects)
	(:label "Browse blocks" :action :browse-code)
	(:label "Browse images" :action :browse-images)
	(:label "Browse sounds" :action :browse-sounds)
	(:label "Browse music" :action :browse-music)
	(:label "Browse fonts" :action :browse-fonts)
	(:label "Browse code" :action :browse-code)))))
    (:label "Tools" 
     :inputs
     ((:label "Create a command prompt" :action :create-prompt)
      (:label "Create a note" :action :create-note)
      (:label "Version control" :action :version-control)))
    (:label "Workspace" :inputs
     ((:label "Switch to workspace" :inputs
	      ((:label "Workspace 1" :action :workspace-1)
	       (:label "Workspace 2" :action :workspace-2)
	       (:label "Workspace 3" :action :workspace-3)
	       (:label "Workspace 4" :action :workspace-4)))
      (:label "Go back to the previous workspace" :action :previous-workspace)
      (:label "Create a new workspace" :action :create-workspace)
      (:label "Rename this workspace" :action :rename-workspace)
      (:label "Delete this workspace" :action :delete-workspace)
      (:label "Workspace settings" :action :configure-workspaces)))
    (:label "Windows"
     :inputs
     ((:label "Create a new window" :action :create-window)
      (:label "Switch to the next window" :action :next-window)
      (:label "Switch to window" :action :switch-window)
      (:label "Close this window" :action :close-window)))
    (:label "Devices"
     :inputs
     ((:label "Browse available devices" :action :browse-devices)
      (:label "Scan for devices" :action :scan-devices)
      (:label "Configure joystick" :action :configure-joystick)
      (:label "Configure camera" :action :configure-camera)
      (:label "Configure microphone" :action :configure-microphone)
      (:label "Configure dance pad" :action :configure-dance-pad)))
    (:label "Help"
     :inputs
     ((:label "General help" :action :general-help)
      (:label "Examples" :action :show-examples)
      (:label "Language Reference" :action :language-reference)
      (:label "Licensing information" :action :licensing-information)))))
    
(defblock system
  (type :initform :system)
  (shell :initform nil)
  (running :initform nil))

(define-method initialize system ()
  (setf *system* self))

(define-method create-prompt system ()
  (add *script* (new listener) 100 100))

(define-method create-project system ())

(define-method open-existing-project system ())
  ;; TODO how to get arguments?
;  (open-project project))

(define-method save-changes system ()
  (save-project))

(define-method save-everything system ()
  (save-project :force))

(define-method ticks system ()
  (get-ticks))

(define-method quit-ioforms system ()
  ;; TODO destroy textures
  (ioforms:quit t))


;; (define-method get-blocks system ()
;;   ^children)

;; (define-method count-blocks system ()
;;   (with-fields (children) self
;;     (apply #'+ (mapcar #'/count children))))

;; (define-method start system ()
;;   (setf ^running t))

;; (define-method stop system ()
;;   (setf ^running nil))

;; (define-method tick system (&rest args)
;;   (with-fields (running children shell) self
;;     (when running
;;       (dolist (block children)
;; 	(apply #'tick block args)))))

;; (define-method resize system (&key height width))

;; (define-method initialize system (&rest args)
  ;; (enable-classic-key-repeat 100 100)
  ;; (labels ((do-resize ()
  ;; 	     (resize *system* 
  ;; 		     :width *screen-width* 
  ;; 		     :height *screen-height*)))
  ;;   (add-hook '*resize-hook* #'do-resize))
  ;; (ioforms:install-blocks self))

;; (define-method new system (project)
;;   (assert (stringp project))
;;   (let ((dir (find-project-path project)))
;;     (when (directory-is-project-p dir)
;;       (error "Project ~S aready exists." project))
;;     (make-directory-maybe dir)
;;     (open-project self project)))
	
;; (define-method run system ()
;;   (run-project *project*)
;;   (run-main-loop))


;; (define-method draw system (destination)
;;   FIXME)

;;; system.lisp ends here
