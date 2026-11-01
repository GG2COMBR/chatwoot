# frozen_string_literal: true

require 'csv'

class Custom::Campaigns::Spreadsheet::CsvReaderService
  pattr_initialize :file_content

  def self.from_attachment(attachment)
    content = attachment.download
    new(content)
  end

  def headers
    normalized = normalized_utf8_content
    return [] if normalized.blank?

    first_line = normalized.each_line(chomp: true).find(&:present?)
    return [] if first_line.blank?

    col_sep = detect_delimiter(first_line)
    parsed = CSV.parse_line(first_line, col_sep: col_sep)
    Array(parsed).map { |h| h.to_s.strip }
  end

  def preview_rows(limit: 5)
    result = []
    each_row_with_hash.with_index(1) do |row_data, index|
      result << row_data
      break if index >= limit
    end
    result
  end

  def each_row_with_hash
    return to_enum(:each_row_with_hash) unless block_given?

    csv = parsed_csv
    return if csv.blank?

    csv.each_with_index do |row, index|
      yield(row_to_hash(row), index + 2)
    end
  end

  def normalized_utf8_content
    return '' if file_content.blank?

    content = file_content.to_s.delete_prefix("\xEF\xBB\xBF") # Remove UTF-8 BOM if present

    if content.dup.force_encoding('UTF-8').valid_encoding?
      content.force_encoding('UTF-8')
    else
      content.encode('UTF-8', 'ISO-8859-1', invalid: :replace, undef: :replace, replace: '')
    end
  rescue StandardError
    file_content.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end

  private

  def parsed_csv
    normalized = normalized_utf8_content
    return if normalized.blank?

    first_line = normalized.each_line(chomp: true).find(&:present?)
    return if first_line.blank?

    col_sep = detect_delimiter(first_line)
    CSV.parse(normalized, headers: true, col_sep: col_sep, skip_blanks: true)
  end

  def row_to_hash(row)
    row_hash = {}
    row.each do |key, value|
      next if key.blank?

      row_hash[key.to_s.strip.downcase] = value.to_s.strip
    end
    row_hash
  end

  def detect_delimiter(line)
    semicolons = line.count(';')
    commas = line.count(',')
    tabs = line.count("\t")

    return ';' if semicolons > commas && semicolons > tabs
    return "\t" if tabs > commas && tabs > semicolons

    ','
  end
end
