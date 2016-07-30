require 'logger'

class MysqlImport
  class Logger < SimpleDelegator
    def initialize(out, debug)
      case out
      when String
        obj = ::Logger.new(out)
      when NilClass
        obj = ::Logger.new(nil)
      when STDOUT, STDERR
        obj = ::Logger.new(out)
        obj.formatter = ->(seveity, datetime, progname, message) { "#{String === message ? message : message.inspect}\n" }
      else
        obj = out
      end

      obj.level = debug ? ::Logger::DEBUG : ::Logger::INFO
      __setobj__(obj)
    end
  end

  module Logging
    def initialize(config, opts = {})
      @logger = Logger.new(opts[:log], opts.fetch(:debug, false))
      embed_logger
      super
    end

    def import(*filters)
      super
    ensure
      logger.info('Imported tables:')
      if result.imported.size > 0
        result.imported.sort.each {|t| logger.info("  #{t[0]} (#{t[1]} sec)") }
      else
        logger.info('  nothing...')
      end
      if result.skipped.size > 0
        logger.info('Skipped tables:')
        result.skipped.sort.each {|t| logger.info("  #{t}") }
      end

      result.clear
    end

    private

    attr_reader :logger

    def parallel_opts
      @parallel_opts ||= super.merge(
        finish: proc do |item, index, _result|
          logger.debug("parallel_item: #{item.inspect}")
          logger.debug("parallel_index: #{index}")
        end
      )
    end

    def embed_logger
      unless LoadDataInfile2::Client.instance_methods.include?(:build_sql_with_logging)
        LoadDataInfile2::Client.class_exec(logger) do |logger|
          define_method :build_sql_with_logging do |file, options = {}|
            build_sql_without_logging(file, options).tap {|sql| logger.debug("sql: #{sql}") }
          end
          alias_method :build_sql_without_logging, :build_sql
          alias_method :build_sql, :build_sql_with_logging
        end
      end
    end
  end

  prepend Logging
end
