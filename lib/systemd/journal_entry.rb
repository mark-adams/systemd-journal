module Systemd
  # Represents a single entry in the Journal.
  class JournalEntry
    include Enumerable

    attr_reader :fields

    # Create a new JournalEntry from the given entry hash. You probably don't
    # need to construct this yourself; instead instances are returned from
    # {Systemd::Journal} methods such as {Systemd::Journal#current_entry}.
    # @param [Hash] entry a hash containing all the key-value pairs associated
    #   with a given journal entry.
    def initialize(entry)
      @entry  = entry
      @fields = entry.map do |key, value|
        name = key.downcase.to_sym
        define_singleton_method(name) { value } unless respond_to?(name)
        name
      end
    end

    # not all journal entries will have all fields.  don't raise an error.
    def method_missing(m)
      nil
    end

    # Get the value of a given field in the entry, or nil if it doesn't exist
    def [](key)
      @entry[key] || @entry[key.to_s.upcase]
    end

    def each
      return to_enum(:each) unless block_given?
      @entry.each { |key, value| yield [key, value] }
    end

    def catalog(opts = {})
      return nil unless catalog?

      opts[:replace] = true unless opts.key?(:replace)

      cat = Systemd::Journal.catalog_for(self[:message_id])
      # catalog_for does not do field substitution for us, so we do it here
      # if requested
      opts[:replace] ? field_substitute(cat) : cat
    end

    def catalog?
      !self[:message_id].nil?
    end

    private

    def field_substitute(msg)
      msg.gsub(/@[A-Z_0-9]+@/) { |field| self[field[1..-2]] || field }
    end
  end
end
