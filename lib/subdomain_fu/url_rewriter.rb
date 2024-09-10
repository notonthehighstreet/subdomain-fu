require 'action_dispatch/routing/route_set'

module ActionDispatch
  module Routing
    class RouteSet #:nodoc:
      # Known Issue: Monkey-patching `url_for` is error-prone.
      # For example, in rails 4.2, the method signature changed from
      #
      #     def url_for(options)
      #
      # to
      #
      #     def url_for(options, route_name = nil, url_strategy = UNKNOWN)
      #
      # Is there an alternative design using composition or class
      # inheritance?

      # override to fix bug when params[:params] is not a HASH. This bug is fixed in newer version of ActionDispath for Rails 7+
      def url_for(options, route_name = nil, url_strategy = ActionDispatch::Routing::RouteSet::UNKNOWN, method_name = nil, reserved = ActionDispatch::Routing::RouteSet::RESERVED_OPTIONS)
        options = default_url_options.merge options

        user = password = nil

        if options[:user] && options[:password]
          user     = options.delete :user
          password = options.delete :password
        end

        recall = options.delete(:_recall) { {} }

        original_script_name = options.delete(:original_script_name)
        script_name = find_script_name options

        if original_script_name
          script_name = original_script_name + script_name
        end

        path_options = options.dup
        reserved.each { |ro| path_options.delete ro }

        route_with_params = generate(route_name, path_options, recall)
        path = route_with_params.path(method_name)
        params = route_with_params.params

        # add the fix from newer version of action_dispatch for params as a key in params
        if options[:params].is_a?(Hash)
          params.merge! options[:params]
        end

        options[:path]        = path
        options[:script_name] = script_name
        options[:params]      = params
        options[:user]        = user
        options[:password]    = password

        url_strategy.call options
      end

      def url_for_with_subdomains(options, *args)
        if SubdomainFu.needs_rewrite?(options[:subdomain], (options[:host] || @request&.host_with_port || "www.#{::AppConfig[:domain]}")) || options[:only_path] == false
          options[:only_path] = false if SubdomainFu.override_only_path?
          options[:host] = SubdomainFu.rewrite_host_for_subdomains(options.delete(:subdomain), options[:host] || @request&.host_with_port || "www.#{::AppConfig[:domain]}")
          # puts "options[:host]: #{options[:host].inspect}"
        else
          options.delete(:subdomain)
        end
        url_for_without_subdomains(options, *args)
      end
      alias_method :url_for_without_subdomains, :url_for
      alias_method :url_for, :url_for_with_subdomains
    end
  end
end
