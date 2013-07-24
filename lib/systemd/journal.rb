require 'systemd/journal/native'
require 'systemd/journal_error'

module Systemd
  class Journal

    def initialize(flags = 0)
      ptr = FFI::MemoryPointer.new(:pointer, 1)
      rc = Native::sd_journal_open(ptr, flags)

      raise JournalError.new(rc) if rc < 0

      @ptr = ptr.read_pointer
      ObjectSpace.define_finalizer(self, self.class.finalize(@ptr))
    end

    def next
      Native::sd_journal_next(@ptr)
    end

    def previous
      Native::sd_journal_previous(@ptr)
    end

    def read_data(field)
      len_ptr = FFI::MemoryPointer.new(:size_t, 1)
      out_ptr = FFI::MemoryPointer.new(:pointer, 1)

      rc = Native::sd_journal_get_data(@ptr, field, out_ptr, len_ptr)

      raise JournalError.new(rc) if rc < 0

      len = read_size_t(len_ptr)
      out_ptr.read_pointer.read_string_length(len)
    end

    def enumerate_data
      len_ptr = FFI::MemoryPointer.new(:size_t, 1)
      out_ptr = FFI::MemoryPointer.new(:pointer, 1)
      results = []

      while true
        rc = Native::sd_journal_enumerate_data(@ptr, out_ptr, len_ptr)
        raise JournalError.new(rc) if rc < 0
        break if rc == 0

        len = read_size_t(len_ptr)
        results.push(out_ptr.read_pointer.read_string_length(len))
        yield results[-1] if block_given?
      end

      results
    end

    def restart_data
      Native::sd_journal_restart_data(@ptr)
    end

    def close!
      Native::sd_journal_close(@ptr)
      @ptr = nil
    end

    private

    def self.finalize(ptr)
      proc{ Native::sd_journal_close(@ptr) unless @ptr.nil? }
    end

    def read_size_t(ptr)
      case ptr.size
      when 8
        ptr.read_uint64
      when 4
        ptr.read_uint32
      else
        raise StandardError.new("Unhandled size_t size: #{ptr.size}")
      end
    end

  end
end
