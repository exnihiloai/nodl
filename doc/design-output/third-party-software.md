# Third-Party Software Inventory & License Obligations

Status: Design output for user story *Uphold 3rd License Obligations*
(`doc/design-input/user-stories/2026-06-06 uphold-license-obligations.md`).
Last regenerated: 2026-06-07.

## Purpose

This document is the complete inventory of third-party software incorporated
into the Nodl application, together with the license under which each component
is used. It is the design-output record that backs the user-facing
acknowledgements page at `/licenses`.

## Scope & method

- **In scope:** everything we redistribute or ship as part of the running
  application — Ruby gems, JavaScript delivered to the browser, CSS frameworks,
  web fonts, and icon assets.
- **Out of scope:** the operating system, its userland, the kernel, the
  container base image, system libraries provided by the OS, and external
  hosted services (e.g. Stripe, the OTLP collector) that we call but do not
  redistribute.
- **Runtime vs. tooling:** gems in Bundler's `default` group are part of the
  deployed application. Gems that are only present in the `development`/`test`
  groups are build/test tooling and are **not** redistributed in the production
  image; they are listed for completeness but do not impose distribution-time
  attribution obligations on the shipped product.

Gem data is derived automatically from the locked dependency tree, so the
`/licenses` page can never silently drift from `Gemfile.lock`:

- **Source of truth:** `ThirdPartyLicenseInventory`
  (`lib/third_party_license_inventory.rb`) reads Bundler's locked `default`
  group and extracts each gem's version, license family, and copyright notice
  from its installed license file.
- **Generated artifact:** `config/third_party_licenses.yml` is produced by
  `bin/rails licenses:generate`. **Do not hand-edit it.**
- **Non-gem assets** (which are not in `Gemfile.lock`) live in
  `config/third_party_assets.yml` and are merged in during generation. DaisyUI's
  version is auto-detected from the vendored CSS banner; the typography plugin,
  Inter, and Lucide carry hand-maintained versions (known gap — no
  machine-readable local version).
- **Drift guard:** `test/lib/third_party_license_inventory_test.rb` rebuilds the
  inventory during `make check` and fails the gate (with copy-pasteable fix
  instructions) whenever the committed YAML no longer matches the bundle.

This document's tables below are a human-readable copy; regenerate them with the
snippet in the maintenance checklist when dependencies change.

## License families in use

| License | Notice / attribution required | Reproduce license text | Notes |
|---|---|---|---|
| MIT | Yes | Yes | Copyright notice + permission text must ship with the software. |
| BSD-2-Clause | Yes | Yes | Must retain copyright notice + conditions + disclaimer. |
| BSD-3-Clause | Yes | Yes | As BSD-2 plus the non-endorsement clause. |
| ISC | Yes | Yes | Functionally equivalent to BSD-2/MIT. Covers the Lucide icons. |
| Apache-2.0 | Yes | Yes | Retain notices; preserve any `NOTICE` file contents; state changes. |
| MPL-2.0 | Yes | Yes (or link) | File-level copyleft; recipients must be able to obtain the license + source of MPL files. |
| Ruby License | Yes | Yes | Ruby stdlib gems; dual-licensed with BSD-2-Clause. |
| SIL OFL 1.1 | Yes | Yes | Covers the Inter typeface. Font may not be sold on its own; RFN rules apply. |
| Prawn License (Ruby / GPLv2 / GPLv3) | Yes | Yes | Prawn family (prawn, pdf-core, ttfunk); we rely on the Ruby-style terms, retaining copyright notices. |

All of the above require that we **mention** the component and **reproduce**
the relevant license text where we distribute the software. The user-facing
`/licenses` page satisfies this for the redistributed components.

## User-facing acknowledgements

- Page: `/licenses` (`LicensesController#show`, view
  `app/views/licenses/show.html.erb`).
- Linked from the About page (`/about`) and the site footer, per the
  acceptance criteria.
- Data source: `config/third_party_licenses.yml` plus the canonical license
  texts in `config/third_party_licenses/*.txt`.
- The page is driven by `ThirdPartyLicenses` (`app/models/third_party_licenses.rb`),
  which groups the redistributed components by license family, reproduces each
  component's copyright notice, and renders the full license text once per
  family.

## Bundled non-gem assets

| Component | Version | License | Copyright | Source |
|---|---|---|---|---|
| Inter (typeface) | shipped as `inter-latin-400-700.woff2` | SIL OFL 1.1 | The Inter Project Authors | https://rsms.me/inter/ |
| Lucide (icons) | SVGs vendored into `app/assets/icons/` | ISC | 2020 Lucide Contributors | https://lucide.dev |
| DaisyUI | 5.0.34 (vendored `app/assets/stylesheets/daisyui.css`) | MIT | Pouya Saadeghi | https://daisyui.com |
| Tailwind CSS | 4.2.0 (via `tailwindcss-ruby`) | MIT | Tailwind Labs / Adam Wathan | https://tailwindcss.com |
| @tailwindcss/typography | 0.5 (build-time plugin) | MIT | Tailwind Labs, Inc. | https://github.com/tailwindlabs/tailwindcss-typography |

> JavaScript shipped to the browser (Turbo, Stimulus, Action Cable) is vendored
> through the `turbo-rails`, `stimulus-rails`, and `actioncable` gems and is
> therefore covered by the gem inventory below (all MIT).

## Runtime gems (redistributed — Bundler `default` group)

| Gem | Version | License | Source |
|---|---|---|---|
| action_text-trix | 2.1.19 | MIT | https://github.com/basecamp/trix |
| actioncable | 8.1.3 | MIT | https://rubyonrails.org |
| actionmailbox | 8.1.3 | MIT | https://rubyonrails.org |
| actionmailer | 8.1.3 | MIT | https://rubyonrails.org |
| actionpack | 8.1.3 | MIT | https://rubyonrails.org |
| actiontext | 8.1.3 | MIT | https://rubyonrails.org |
| actionview | 8.1.3 | MIT | https://rubyonrails.org |
| activejob | 8.1.3 | MIT | https://rubyonrails.org |
| activemodel | 8.1.3 | MIT | https://rubyonrails.org |
| activerecord | 8.1.3 | MIT | https://rubyonrails.org |
| activestorage | 8.1.3 | MIT | https://rubyonrails.org |
| activesupport | 8.1.3 | MIT | https://rubyonrails.org |
| afm | 1.0.0 | MIT | http://github.com/halfbyte/afm |
| ansi | 1.6.0 | BSD-2-Clause | https://github.com/rubyworks/ansi |
| Ascii85 | 2.0.1 | MIT | https://github.com/DataWraith/ascii85gem/ |
| ast | 2.4.3 | MIT | https://whitequark.github.io/ast/ |
| async | 2.39.0 | MIT | https://github.com/socketry/async |
| async-http | 0.95.1 | MIT | https://github.com/socketry/async-http |
| async-pool | 0.11.2 | MIT | https://github.com/socketry/async-pool |
| async-websocket | 0.30.0 | MIT | https://github.com/socketry/async-websocket |
| base64 | 0.3.0 | Ruby/BSD-2-Clause | https://github.com/ruby/base64 |
| bcrypt | 3.1.22 | MIT | https://github.com/bcrypt-ruby/bcrypt-ruby |
| bcrypt_pbkdf | 1.1.2 | MIT | https://github.com/net-ssh/bcrypt_pbkdf-ruby |
| bigdecimal | 3.3.1 | Ruby/BSD-2-Clause | https://github.com/ruby/bigdecimal |
| bootsnap | 1.24.6 | MIT | https://github.com/rails/bootsnap |
| builder | 3.3.0 | MIT | https://github.com/rails/builder |
| bundler | 2.5.22 | MIT | https://bundler.io |
| concurrent-ruby | 1.3.6 | MIT | http://www.concurrent-ruby.com |
| connection_pool | 3.0.2 | MIT | https://github.com/mperham/connection_pool |
| console | 1.36.0 | MIT | https://github.com/socketry/console |
| crass | 1.0.6 | MIT | https://github.com/rgrove/crass/ |
| date | 3.5.1 | Ruby/BSD-2-Clause | https://github.com/ruby/date |
| docx | 0.13.0 | MIT | https://github.com/chrahunt/docx |
| dotenv | 3.2.0 | MIT | https://github.com/bkeepers/dotenv |
| drb | 2.2.3 | Ruby/BSD-2-Clause | https://github.com/ruby/drb |
| ed25519 | 1.4.0 | MIT | https://github.com/RubyCrypto/ed25519 |
| erb | 6.0.4 | Ruby/BSD-2-Clause | https://github.com/ruby/erb |
| erubi | 1.13.1 | MIT | https://github.com/jeremyevans/erubi |
| et-orbi | 1.4.0 | MIT | https://github.com/floraison/et-orbi |
| ffi | 1.17.3 | BSD-3-Clause | https://github.com/ffi/ffi/wiki |
| fiber-annotation | 0.2.0 | MIT | https://github.com/ioquatix/fiber-annotation |
| fiber-local | 1.1.0 | MIT | https://github.com/socketry/fiber-local |
| fiber-storage | 1.0.1 | MIT | https://github.com/ioquatix/fiber-storage |
| fugit | 1.12.2 | MIT | https://github.com/floraison/fugit |
| globalid | 1.3.0 | MIT | http://www.rubyonrails.org |
| google-protobuf | 4.35.0 | BSD-3-Clause | https://developers.google.com/protocol-buffers |
| googleapis-common-protos-types | 1.23.0 | Apache-2.0 | https://github.com/googleapis/common-protos-ruby |
| hashery | 2.1.2 | BSD-2-Clause | http://rubyworks.github.com/hashery |
| htmltoword | 1.1.1 | MIT | http://github.com/karnov/htmltoword |
| i18n | 1.14.8 | MIT | https://github.com/ruby-i18n/i18n |
| image_processing | 1.14.0 | MIT | https://github.com/janko/image_processing |
| importmap-rails | 2.2.3 | MIT | https://github.com/rails/importmap-rails |
| io-console | 0.8.2 | Ruby/BSD-2-Clause | https://github.com/ruby/io-console |
| io-endpoint | 0.17.2 | MIT | https://github.com/socketry/io-endpoint |
| io-event | 1.16.1 | MIT | https://github.com/socketry/io-event |
| io-stream | 0.13.0 | MIT | https://github.com/socketry/io-stream |
| irb | 1.18.0 | Ruby/BSD-2-Clause | https://github.com/ruby/irb |
| jbuilder | 2.15.1 | MIT | https://github.com/rails/jbuilder |
| json | 2.19.8 | Ruby | https://github.com/ruby/json |
| kamal | 2.11.0 | MIT | https://github.com/basecamp/kamal |
| kramdown | 2.4.0 | MIT | http://kramdown.gettalong.org |
| logger | 1.7.0 | Ruby/BSD-2-Clause | https://github.com/ruby/logger |
| loofah | 2.25.1 | MIT | https://github.com/flavorjones/loofah |
| mail | 2.9.0 | MIT | https://github.com/mikel/mail |
| marcel | 1.2.1 | MIT/Apache-2.0 | https://github.com/rails/marcel |
| matrix | 0.4.3 | Ruby/BSD-2-Clause | https://github.com/ruby/matrix |
| metrics | 0.15.0 | MIT | https://github.com/socketry/metrics |
| mini_magick | 5.3.1 | MIT | https://github.com/minimagick/minimagick |
| mini_mime | 1.1.5 | MIT | https://github.com/discourse/mini_mime |
| minitest | 6.0.6 | MIT | https://minite.st/ |
| msgpack | 1.8.1 | Apache-2.0 | https://msgpack.org/ |
| net-imap | 0.6.4 | Ruby/BSD-2-Clause | https://github.com/ruby/net-imap |
| net-pop | 0.1.2 | Ruby/BSD-2-Clause | https://github.com/ruby/net-pop |
| net-protocol | 0.2.2 | Ruby/BSD-2-Clause | https://github.com/ruby/net-protocol |
| net-scp | 4.1.0 | MIT | https://github.com/net-ssh/net-scp |
| net-sftp | 4.0.0 | MIT | https://github.com/net-ssh/net-sftp |
| net-smtp | 0.5.1 | Ruby/BSD-2-Clause | https://github.com/ruby/net-smtp |
| net-ssh | 7.3.2 | MIT | https://github.com/net-ssh/net-ssh |
| nio4r | 2.7.5 | MIT/BSD-2-Clause | https://github.com/socketry/nio4r |
| nokogiri | 1.19.3 | MIT | https://nokogiri.org |
| oga | 3.4 | MPL-2.0 | https://gitlab.com/yorickpeterse/oga/ |
| opentelemetry-api | 1.10.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-common | 0.25.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-exporter-otlp | 0.34.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-exporter-otlp-logs | 0.5.1 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-exporter-otlp-metrics | 0.9.1 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-instrumentation-action_mailer | 0.8.1 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-action_pack | 0.18.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-action_view | 0.13.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-active_job | 0.12.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-active_record | 0.13.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-active_storage | 0.5.1 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-active_support | 0.12.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-base | 0.26.1 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-concurrent_ruby | 0.25.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-logger | 0.4.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-rack | 0.31.1 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-instrumentation-rails | 0.42.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby-contrib |
| opentelemetry-logs-api | 0.4.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-logs-sdk | 0.6.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-metrics-api | 0.6.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-metrics-sdk | 0.14.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-registry | 0.6.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-sdk | 1.12.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| opentelemetry-semantic_conventions | 1.39.0 | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-ruby |
| ostruct | 0.6.3 | Ruby/BSD-2-Clause | https://github.com/ruby/ostruct |
| pdf-core | 0.10.0 | Nonstandard/GPL-2.0-only/GPL-3.0-only | http://prawnpdf.org/ |
| pdf-reader | 2.15.1 | MIT | https://github.com/yob/pdf-reader |
| pg | 1.6.3 | BSD-2-Clause | https://github.com/ged/ruby-pg |
| pp | 0.6.3 | Ruby/BSD-2-Clause | https://github.com/ruby/pp |
| prawn | 2.5.0 | Nonstandard/GPL-2.0-only/GPL-3.0-only | http://prawnpdf.org/ |
| prawn-html | 0.7.1 | MIT | https://github.com/blocknotes/prawn-html |
| prettyprint | 0.2.0 | Ruby/BSD-2-Clause | https://github.com/ruby/prettyprint |
| prism | 1.9.0 | MIT | https://github.com/ruby/prism |
| propshaft | 1.3.2 | MIT | https://github.com/rails/propshaft |
| protocol-hpack | 1.5.1 | MIT | https://github.com/socketry/http-hpack |
| protocol-http | 0.62.2 | MIT | https://github.com/socketry/protocol-http |
| protocol-http1 | 0.39.0 | MIT | https://github.com/socketry/protocol-http1 |
| protocol-http2 | 0.26.0 | MIT | https://github.com/socketry/protocol-http2 |
| protocol-rack | 0.22.1 | MIT | https://github.com/socketry/protocol-rack |
| protocol-url | 0.4.0 | MIT | https://github.com/socketry/protocol-url |
| protocol-websocket | 0.21.1 | MIT | https://github.com/socketry/protocol-websocket |
| psych | 5.4.0 | MIT | https://github.com/ruby/psych |
| puma | 8.0.2 | BSD-3-Clause | https://puma.io |
| raabro | 1.4.0 | MIT | https://github.com/floraison/raabro |
| racc | 1.8.1 | Ruby/BSD-2-Clause | https://github.com/ruby/racc |
| rack | 3.2.6 | MIT | https://github.com/rack/rack |
| rack-attack | 6.8.0 | MIT | https://github.com/rack/rack-attack |
| rack-session | 2.1.2 | MIT | https://github.com/rack/rack-session |
| rack-test | 2.2.0 | MIT | https://github.com/rack/rack-test |
| rackup | 2.3.1 | MIT | https://github.com/rack/rackup |
| rails | 8.1.3 | MIT | https://rubyonrails.org |
| rails-dom-testing | 2.3.0 | MIT | https://github.com/rails/rails-dom-testing |
| rails-html-sanitizer | 1.7.0 | MIT | https://github.com/rails/rails-html-sanitizer |
| railties | 8.1.3 | MIT | https://rubyonrails.org |
| rake | 13.4.2 | MIT | https://github.com/ruby/rake |
| rdoc | 7.2.0 | Ruby | https://ruby.github.io/rdoc |
| reline | 0.6.3 | Ruby | https://github.com/ruby/reline |
| rexml | 3.4.4 | BSD-2-Clause | https://github.com/ruby/rexml |
| ruby-ll | 2.1.4 | MPL-2.0 | https://github.com/yorickpeterse/ruby-ll |
| ruby-rc4 | 0.1.5 | see notes | http://www.caigenichols.com/ |
| ruby-vips | 2.3.0 | MIT | http://github.com/libvips/ruby-vips |
| rubyzip | 3.3.1 | BSD-2-Clause | http://github.com/rubyzip/rubyzip |
| securerandom | 0.4.1 | Ruby/BSD-2-Clause | https://github.com/ruby/securerandom |
| solid_cable | 3.0.12 | MIT | https://github.com/rails/solid_cable |
| solid_cache | 1.0.10 | MIT | http://github.com/rails/solid_cache |
| solid_queue | 1.4.0 | MIT | https://github.com/rails/solid_queue |
| sshkit | 1.25.0 | MIT | http://github.com/capistrano/sshkit |
| stimulus-rails | 1.3.4 | MIT | https://stimulus.hotwired.dev |
| stringio | 3.2.0 | Ruby/BSD-2-Clause | https://github.com/ruby/stringio |
| stripe | 13.5.1 | MIT | https://stripe.com/docs/api?lang=ruby |
| strong_migrations | 2.8.0 | MIT | https://github.com/ankane/strong_migrations |
| tailwindcss-rails | 4.4.0 | MIT | https://github.com/rails/tailwindcss-rails |
| tailwindcss-ruby | 4.2.0 | MIT | https://github.com/flavorjones/tailwindcss-ruby |
| thor | 1.5.0 | MIT | https://github.com/rails/thor |
| thruster | 0.1.21 | MIT | https://github.com/basecamp/thruster |
| timeout | 0.6.1 | Ruby/BSD-2-Clause | https://github.com/ruby/timeout |
| traces | 0.18.2 | MIT | https://github.com/socketry/traces |
| tsort | 0.2.0 | Ruby/BSD-2-Clause | https://github.com/ruby/tsort |
| ttfunk | 1.8.0 | Nonstandard/GPL-2.0-only/GPL-3.0-only | http://prawnpdf.org/ |
| turbo-rails | 2.0.23 | MIT | https://github.com/hotwired/turbo-rails |
| tzinfo | 2.0.6 | MIT | https://tzinfo.github.io |
| uri | 1.1.1 | Ruby/BSD-2-Clause | https://github.com/ruby/uri |
| useragent | 0.16.11 | MIT | https://github.com/gshutler/useragent |
| websocket-driver | 0.8.1 | Apache-2.0 | https://github.com/faye/websocket-driver-ruby |
| websocket-extensions | 0.1.5 | Apache-2.0 | https://github.com/faye/websocket-extensions-ruby |
| zeitwerk | 2.8.2 | MIT | https://github.com/fxn/zeitwerk |

## Development & test tooling (not redistributed)

These gems are present only in the `development`/`test` groups. They are not
part of the production image and are listed for completeness.

| Gem | Version | License | Source |
|---|---|---|---|
| addressable | 2.9.0 | Apache-2.0 | https://github.com/sporkmonger/addressable |
| bindex | 0.8.1 | MIT | https://github.com/gsamokovarov/bindex |
| brakeman | 8.0.4 | Brakeman Public Use License | https://brakemanscanner.org |
| bundler-audit | 0.9.3 | GPL-3.0-or-later | https://github.com/rubysec/bundler-audit#readme |
| capybara | 3.40.0 | MIT | https://github.com/teamcapybara/capybara |
| database_consistency | 3.0.5 | MIT | https://github.com/djezzzl/database_consistency |
| debug | 1.11.1 | Ruby/BSD-2-Clause | https://github.com/ruby/debug |
| docile | 1.4.1 | MIT | https://ms-ati.github.io/docile/ |
| language_server-protocol | 3.17.0.5 | MIT | https://github.com/mtsmfm/language_server-protocol-ruby |
| lint_roller | 1.1.0 | MIT | https://github.com/standardrb/lint_roller |
| mocha | 3.1.0 | MIT/BSD-2-Clause | https://mocha.jamesmead.org |
| parallel | 1.27.0 | MIT | https://github.com/grosser/parallel |
| parser | 3.3.10.2 | MIT | https://github.com/whitequark/parser |
| public_suffix | 7.0.5 | MIT | https://simonecarletti.com/code/publicsuffix-ruby |
| rainbow | 3.1.1 | MIT | https://github.com/sickill/rainbow |
| regexp_parser | 2.11.3 | MIT | https://github.com/ammar/regexp_parser |
| rubocop | 1.84.2 | MIT | https://github.com/rubocop/rubocop |
| rubocop-ast | 1.49.0 | MIT | https://github.com/rubocop/rubocop-ast |
| rubocop-performance | 1.26.1 | MIT | https://github.com/rubocop/rubocop-performance |
| rubocop-rails | 2.34.3 | MIT | https://github.com/rubocop/rubocop-rails |
| rubocop-rails-omakase | 1.1.0 | MIT | https://github.com/rails/rubocop-rails-omakase |
| ruby-progressbar | 1.13.0 | MIT | https://github.com/jfelchner/ruby-progressbar |
| ruby2_keywords | 0.0.5 | Ruby/BSD-2-Clause | https://github.com/ruby/ruby2_keywords |
| selenium-webdriver | 4.44.0 | Apache-2.0 | https://selenium.dev |
| simplecov | 0.22.0 | MIT | https://github.com/simplecov-ruby/simplecov |
| simplecov-html | 0.13.2 | MIT | https://github.com/simplecov-ruby/simplecov-html |
| simplecov_json_formatter | 0.1.4 | MIT | https://github.com/fede-moya/simplecov_json_formatter |
| unicode-display_width | 3.2.0 | MIT | https://github.com/janlelis/unicode-display_width |
| unicode-emoji | 4.2.0 | MIT | https://github.com/janlelis/unicode-emoji |
| web-console | 4.3.0 | MIT | https://github.com/rails/web-console |
| websocket | 1.2.11 | MIT | http://github.com/imanel/websocket-ruby |
| xpath | 3.2.0 | MIT | https://github.com/teamcapybara/xpath |

## Notes on individual components

- **ruby-rc4 (0.1.5):** its gemspec declares no SPDX license; upstream
  distributes it under the MIT License (see the project's `README`/notice).
  Treated as MIT on the `/licenses` page.
- **Prawn family (prawn, pdf-core, ttfunk):** released under a Ruby-style
  tri-license (Ruby License / GPLv2 / GPLv3). We rely on the Ruby-style terms,
  which require retaining the original copyright notices and disclaimers.
- **marcel:** dual MIT/Apache-2.0; listed under MIT. Apache's `NOTICE`
  obligations do not add content here.
- **OpenTelemetry gems:** Apache-2.0; the upstream repositories carry no
  component-specific `NOTICE` content beyond the standard copyright line
  ("Copyright The OpenTelemetry Authors"), which is reproduced on the page.
- **Inter (OFL 1.1):** the Reserved Font Name and "no selling the font by
  itself" conditions are respected — we embed the font as part of the
  application UI only.

## Maintenance checklist (run on dependency changes)

The drift guard makes this mostly mechanical — `make check` tells you when the
inventory is stale and prints the exact fix steps. The full loop:

1. Change a dependency (`Gemfile`, vendored asset, or `config/third_party_assets.yml`)
   and re-resolve.
2. Run `bin/rails licenses:generate` to rewrite `config/third_party_licenses.yml`.
3. Review `git diff -- config/third_party_licenses.yml`. For any **newly added**
   component, sanity-check the auto-inferred copyright notice; if a gem's license
   file leads with boilerplate, add a corrected line to
   `ThirdPartyLicenseInventory::OVERRIDES`.
4. If a **new license family** appears, the generator/guard will fail loudly:
   add its raw license string to `FAMILIES`, its display name + body file to
   `GROUP_META`, and the canonical text at
   `config/third_party_licenses/<body_file>`.
5. Refresh the runtime/dev tables in this document (re-extract with the snippet
   below).
6. Run `make check` until green and commit.

```ruby
# bin/rails runner, or inside the web container — for refreshing the tables here
require "bundler"
Bundler.load.specs.to_a.uniq(&:name).sort_by(&:name).each do |s|
  puts [s.name, s.version, Array(s.licenses).join("/"), s.homepage].join("\t")
end
```
