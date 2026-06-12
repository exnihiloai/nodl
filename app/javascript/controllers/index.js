// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import BouncyController from "controllers/bouncy_controller"
import RevealController from "controllers/reveal_controller"
import ThemeController from "controllers/theme_controller"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

// Body-level controllers: eager so nav theme toggle and reveal are instant.
application.register("theme", ThemeController)
application.register("reveal", RevealController)
application.register("bouncy", BouncyController)

lazyLoadControllersFrom("controllers", application)
