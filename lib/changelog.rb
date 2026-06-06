# frozen_string_literal: true

require "erb"

class Changelog
  Entry = Data.define(:version, :date, :sections) do
    def slug = "v#{version}"
    def modal_id = "cl-#{slug}"
  end

  Section = Data.define(:key, :items)
  Item = Data.define(:html, :indent, :title)
  WeekColumn = Data.define(:key, :label, :subtitle, :entries)

  VERSION_HEADING = /\A## \[(?<version>[^\]]+)\] - (?<date>\d{4}-\d{2}-\d{2})\z/
  SECTION_HEADING = /\A###\s+(?<title>.+)\z/
  BULLET_LINE = /\A(?<indent>\s*)-\s+(?<text>.+)\z/
  BOLD_INLINE = /\*\*(.+?)\*\*/
  CODE_INLINE = /`([^`]+)`/
  ITEM_TITLE = /\A\*\*(?<title>.+?):\*\*\s*(?<rest>.*)\z/

  SECTION_KEYS = {
    "Added" => :added,
    "Fixed" => :fixed,
    "Changed" => :changed,
    "Removed" => :removed,
    "Security" => :security,
    "Technical" => :technical
  }.freeze

  ROMAN_NUMERALS = { 1 => "I", 2 => "II", 3 => "III", 4 => "IV", 5 => "V" }.freeze
  CACHE_TTL = 60

  class << self
    def week_columns
      entries = changelog_entries
      groups = entries.group_by do |entry|
        year, month, day = entry.date.split("-").map(&:to_i)
        week = [ ((day - 1) / 7) + 1, 5 ].min
        [ year, month, week ]
      end

      groups.sort.map do |(year, month, week), items|
        sorted_entries = items.sort_by(&:date).reverse
        count = sorted_entries.size
        WeekColumn.new(
          key: format("%04d-%02d-%d", year, month, week),
          label: week_label(year, month, week),
          subtitle: I18n.t("changelog.column_subtitle", count: count),
          entries: sorted_entries
        )
      end
    end

    def changelog_entries
      path = AppVersion.changelog_path
      return [] unless path.file?

      mtime = path.mtime.to_i
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if @cached_entries && @cached_mtime == mtime && now - @cached_at < CACHE_TTL
        return @cached_entries
      end

      @cached_entries = parse(path.read)
      @cached_mtime = mtime
      @cached_at = now
      @cached_entries
    end

    def reset_cache!
      @cached_entries = nil
      @cached_mtime = nil
      @cached_at = nil
    end

    def format_inline(text)
      escaped = ERB::Util.html_escape(text).to_s
      escaped = escaped.gsub(CODE_INLINE, '<code class="font-mono text-xs bg-base-200 rounded px-1">\1</code>')
      escaped.gsub(BOLD_INLINE, "<strong>\\1</strong>").html_safe
    end

    private

    def parse(text)
      parser = ParserState.new
      text.each_line { |raw| parser.consume(raw.rstrip) }
      parser.finish
      parser.entries
    end

    def week_label(year, month, week)
      roman = ROMAN_NUMERALS.fetch(week, week.to_s)
      month_name = I18n.t("changelog.months.#{month}", default: month.to_s)
      I18n.t("changelog.week_label", month: month_name, year: year, week: roman)
    end
  end

  class ParserState
    def initialize
      @entries = []
      @current_entry = nil
      @current_sections = []
      @current_section_key = nil
      @current_items = []
    end

    attr_reader :entries

    def consume(line)
      return if line.empty?

      if (match = line.match(VERSION_HEADING))
        flush_section
        flush_entry
        @current_entry = { version: match[:version].strip, date: match[:date] }
        return
      end

      if (match = line.match(SECTION_HEADING)) && @current_entry
        flush_section
        @current_section_key = SECTION_KEYS.fetch(match[:title].strip, :other)
        return
      end

      return unless (match = line.match(BULLET_LINE)) && @current_entry && @current_section_key

      @current_items << build_item(match)
    end

    def build_item(match)
      indent_level = [ match[:indent].length / 2, 0 ].max
      item_text = match[:text].strip
      title = nil
      content_text = item_text

      if (title_match = item_text.match(ITEM_TITLE))
        title = title_match[:title].strip
        content_text = title_match[:rest].strip
      end

      Item.new(html: Changelog.format_inline(content_text), indent: indent_level, title: title)
    end

    def flush_section
      if @current_section_key && @current_items.any?
        @current_sections << Section.new(key: @current_section_key, items: @current_items)
      end
      @current_section_key = nil
      @current_items = []
    end

    def flush_entry
      if @current_entry && @current_sections.any?
        @entries << Entry.new(
          version: @current_entry[:version],
          date: @current_entry[:date],
          sections: @current_sections
        )
      end
      @current_sections = []
    end

    def finish
      flush_section
      flush_entry
    end
  end
  private_constant :ParserState
end
