# -*- encoding: utf-8 -*-
#
# Author:: Robert Reilly (<robert_reilly@surveysampling.com>)
#
# Copyright (C) 2017, Robert Reilly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'
require 'kitchen/driver/propeller_version'
require  'json'
require 'net/http'
require 'rubygems'

module Kitchen
  module Driver
    class Propeller < Kitchen::Driver::Base
     kitchen_driver_api_version 2
     plugin_version Kitchen::Driver::PROPELLER_VERSION
      config(:vmName) do |driver|
        "#{driver.instance.name}-#{SecureRandom.hex(4)}"
      end

      config :driver_options,
       :tenantName => 'CTQ-LAB',
       :vmName => 'test-kitchen.utl'
    
      def create(state)
      puts "Building Machine: #{config[:vmName]}"
      
      kitchenData = { 
                      :tenantName => config[:tenantName],
                      :request => 
                                  [{
                                    :vmName => config[:vmName],
                                  }]
                      }
                    

        @state = state
        # validate_vm_settings 
        validate_vm_settings(config)
        return if vm_exists
        info("Creating virtual machine for #{instance.name}.")
        uri = URI(config[:endpoint])
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = kitchenData.to_json
        res = Net::HTTP.start(uri.hostname, uri.port) do |http|
          res = http.request(req)
          if ENV['DRIVER_DEBUG'] == 1
            puts "response #{res.body}"
          end
    
        vmo = JSON.parse(res.body)
        sdat = vmo[0]
        puts sdat["serverId"]
        @state[:id] = sdat["serverId"]
        info("Propeller instance #{instance.to_str} created.")
        end
      end

      def destroy(state)
        @state = state
        #return unless vm_exists

        instance.transport.connection(state).close
        info("Destroying virtual machine for #{instance.name}.")

        puts state[:id]

        uri = URI("#{config[:endpoint]}#{state[:id]}") 
        req = Net::HTTP::Delete.new(uri, 'Content-Type' => 'application/json')
        req.body = "user:robert_reilly@surveysampling.com"

        res = Net::HTTP.start(uri.hostname, uri.port) do |http|
          res = http.request(req)
          puts "response #{res.body}"
        end
        info("The Propeller instance #{instance.to_str} has been removed.")

        state.delete(:id)
      end

      private

      def validate_vm_settings(config)
        raise "Missing tenantName" unless config[:tenantName?]
        raise "Missing tenantName" unless config[:vmName?]
      end
       



      def update_state
        vm_details
        @state[:id] = @vm['Id']
        @state[:hostname] = @vm['IpAddress']
        @state[:vm_name] = @vm['Name']
      end

      def vm_details
        run_ps set_vm_ipaddress_ps if config[:ip_address]
        @vm = run_ps vm_details_ps
      end

      def vm_exists
        info('Checking for existing virtual machine.')
        return false unless @state.key?(:id) && !@state[:id].nil?
        existing_vm = run_ps ensure_vm_running_ps
        return false if existing_vm.nil? || existing_vm['Id'].nil?
        info("Found an exising VM with an ID: #{existing_vm['Id']}")
        true
      end

      def kitchen_vm_path
        @kitchen_vm_path ||= File.join(config[:kitchen_root], ".kitchen/#{instance.name}")
      end

    end
  end
end
