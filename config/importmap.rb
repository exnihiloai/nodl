# Pin npm packages by running ./bin/importmap

pin "application"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "marked", to: "vendor/marked.js", preload: false
pin "turndown", to: "vendor/turndown.js", preload: false
pin "three", to: "vendor/three.js", preload: false # @0.170.0 — hero spectrogram only, after idle
