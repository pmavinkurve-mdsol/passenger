#!/usr/bin/env ruby
# encoding: binary
#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2013-2017 Phusion Holding B.V.
#
#  "Passenger", "Phusion Passenger" and "Union Station" are registered
#  trademarks of Phusion Holding B.V.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

module PhusionPassenger
  module App
    def self.options
      @@options
    end

    def self.app
      @@app
    end

    def self.format_exception(e)
      result = "#{e} (#{e.class})"
      if !e.backtrace.empty?
        result << "\n  " << e.backtrace.join("\n  ")
      end
      result
    end

    def self.exit_code_for_exception(e)
      if e.is_a?(SystemExit)
        e.status
      else
        1
      end
    end

    def self.read_startup_arguments
      STDOUT.sync = true
      STDERR.sync = true

      dir = ENV['PASSENGER_SPAWN_WORK_DIR']
      if dir.nil? || dir.empty?
        abort 'PASSENGER_SPAWN_WORK_DIR not set'
      end

      @@options = {}
      Dir["#{dir}/args/*"].each do |path|
        name = File.basename(path)
        @@options[name] = File.open(path, 'rb') do |f|
          f.read
        end
      end
    end

    def self.init_passenger
      require "#{options["ruby_libdir"]}/phusion_passenger"
      PhusionPassenger.locate_directories(options["passenger_root"])
      PhusionPassenger.require_passenger_lib 'native_support'
      PhusionPassenger.require_passenger_lib 'ruby_core_enhancements'
      PhusionPassenger.require_passenger_lib 'ruby_core_io_enhancements'
      PhusionPassenger.require_passenger_lib 'loader_shared_helpers'
      PhusionPassenger.require_passenger_lib 'request_handler'
      PhusionPassenger.require_passenger_lib 'rack/thread_handler_extension'
      @@options = LoaderSharedHelpers.init(@@options)
      if defined?(NativeSupport)
        NativeSupport.disable_stdio_buffering
      end
      RequestHandler::ThreadHandler.send(:include, Rack::ThreadHandlerExtension)
    rescue Exception => e
      if defined?(LoaderSharedHelpers)
        LoaderSharedHelpers.report_exception(options, e)
        LoaderSharedHelpers.about_to_abort(options, e)
      else
        puts format_exception(e)
      end
      exit exit_code_for_exception(e)
    end

    def self.load_app
      LoaderSharedHelpers.before_loading_app_code_step1('config.ru', options)
      LoaderSharedHelpers.run_load_path_setup_code(options)
      LoaderSharedHelpers.before_loading_app_code_step2(options)
      LoaderSharedHelpers.activate_gem 'rack'

      app_root = options["app_root"]
      rackup_file = LoaderSharedHelpers.maybe_make_path_relative_to_app_root(
        app_root, options["startup_file"] || "#{app_root}/config.ru")
      rackup_code = ::File.open(rackup_file, 'rb') do |f|
        f.read
      end
      @@app = eval("Rack::Builder.new {( #{rackup_code}\n )}.to_app",
        TOPLEVEL_BINDING, rackup_file)

      LoaderSharedHelpers.after_loading_app_code(options)
    rescue Exception => e
      LoaderSharedHelpers.report_app_exception(options, e)
      LoaderSharedHelpers.about_to_abort(options, e)
      exit exit_code_for_exception(e)
    end


    ################## Main code ##################


    read_startup_arguments
    init_passenger
    load_app
    LoaderSharedHelpers.before_handling_requests(false, options)
    handler = RequestHandler.new(STDIN, options.merge("app" => app))
    LoaderSharedHelpers.advertise_sockets(options, handler)
    LoaderSharedHelpers.advertise_readiness(options)
    handler.main_loop
    handler.cleanup
    LoaderSharedHelpers.after_handling_requests

  end # module App
end # module PhusionPassenger
