require 'grape'

module NewRelic
  module Agent
    module Instrumentation
      class Grape < ::Grape::Middleware::Base
        def before
          NewRelic::Agent.set_transaction_name(transaction_name, :category => :rack)
        end

        def _nr_has_middleware_tracing
          true
        end

        private

        def transaction_name
          "#{api_class}/#{route_method} #{route_path}"
        end

        def api_class
          env['api.endpoint'].source.binding.eval('self')
        end

        def route_method
          route.route_method.upcase
        end

        def route_path
          "#{route.route_version}.#{route.route_path.gsub(/^.+:version\/|^\/|:|\(.+\)/, '').tr('/', '-')}"
        end

        def route
          env['api.endpoint'].routes.first
        end
      end
    end
  end
end

DependencyDetection.defer do
  @name = :grape

  depends_on do
    !::NewRelic::Control.instance['disable_grape'] && !ENV['DISABLE_NEW_RELIC_GRAPE']
  end

  executes do
    NewRelic::Agent.logger.info 'Installing Grape instrumentation'
  end

  executes do
    module Grape
      class Endpoint
        def call!(env)
          extend helpers

          env['api.endpoint'] = self
          if options[:app]
            options[:app].call(env)
          else
            builder = build_middleware
            builder.run NewRelic::Agent::Instrumentation::Grape.new(lambda { |arg| run(arg) })
            builder.call(env)
          end
        end
      end
    end
  end
end
