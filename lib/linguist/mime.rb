require 'mime/types'
require 'yaml'

module MIME
  class Type
    attr_accessor :binary

    undef_method :binary?
    def binary?
      if defined? @binary
        @binary
      elsif media_type == 'text'
        false
      else
        @encoding == 'base64'
      end
    end

    attr_accessor :attachment

    def attachment?
      if defined? @attachment
        @attachment
      else
        binary?
      end
    end
  end
end

# Register additional mime type extensions
mime_extensions = YAML.load_file(File.expand_path("../mimes.yml", __FILE__))
mime_extensions.each do |mime_type, options|
  mime = MIME::Types[mime_type].first || MIME::Type.new(mime_type)

  (options['extensions'] || []).each { |ext| mime.extensions << ext }

  mime.binary     = options['binary']     if options.key?('binary')
  mime.attachment = options['attachment'] if options.key?('attachment')

  MIME::Types.add_type_variant(mime)
  MIME::Types.index_extensions(mime)
end

module Linguist
  module Mime
    # Internal: Look up mime type for extension.
    #
    # ext - The extension String. May include leading "."
    #
    # Examples
    #
    #   Mime.mime_for('.html')
    #   # => 'text/html'
    #
    #   Mime.mime_for('txt')
    #   # => 'text/plain'
    #
    # Return mime type String otherwise falls back to 'text/plain'.
    def self.mime_for(ext)
      ext ||= ''
      guesses = ::MIME::Types.type_for(ext)
      guesses.first ? guesses.first.simplified : 'text/plain'
    end

    Special = YAML.load_file(File.expand_path("../content_types.yml", __FILE__))

    # Internal: Look up Content-Type header to serve for extension.
    #
    # This value is used when serving raw blobs.
    #
    #   /github/linguist/raw/master/lib/linguist/mime.rb
    #
    # ext - The extension String. May include leading "."
    #
    #   Mime.content_type_for('.html')
    #   # => 'text/plain; charset=utf-8'
    #
    # Return Content-Type String otherwise falls back to
    # 'text/plain; charset=utf-8'.
    def self.content_type_for(ext)
      ext ||= ''

      # Lookup mime type
      type = mime_for(ext)

      # Substitute actual mime type if an override exists in content_types.yml
      type = Special[type] || Special[ext.sub(/^\./, '')] || type

      # Append default charset to text files
      type += '; charset=utf-8' if type =~ /^text\//

      type
    end

    # Internal: Determine if extension or mime type is binary.
    #
    # ext_or_mime_type - A file extension ".txt" or mime type "text/plain".
    #
    # Returns true or false
    def self.binary?(ext_or_mime_type)
      mime_type = lookup_mime_type_for(ext_or_mime_type)
      mime_type.nil? || mime_type.binary?
    end

    # Internal: Determine if extension or mime type is an attachment.
    #
    # ext_or_mime_type - A file extension ".txt" or mime type "text/plain".
    #
    # Attachments are files that should be downloaded rather than be
    # displayed in the browser.
    #
    # This is used to set our Content-Disposition headers.
    #
    # Attachment files should generally binary files but non-
    # attachments do not imply plain text. For an example Images are
    # not treated as attachments.
    #
    # Returns true or false
    def self.attachment?(ext_or_mime_type)
      mime_type = lookup_mime_type_for(ext_or_mime_type)
      mime_type.nil? || mime_type.attachment?
    end

    # Internal: Lookup mime type for extension or mime type
    #
    # Returns a MIME::Type
    def self.lookup_mime_type_for(ext_or_mime_type)
      ext_or_mime_type ||= ''

      if ext_or_mime_type =~ /\w+\/\w+/
        guesses = ::MIME::Types[ext_or_mime_type]
      else
        guesses = ::MIME::Types.type_for(ext_or_mime_type)
      end

      guesses.first
    end
  end
end
