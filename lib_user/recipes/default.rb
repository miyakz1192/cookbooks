#
# Cookbook Name:: lib_user
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
#
#

Chef::Resource::File.send(:include, IniFileHelper)

file "/etc/neutron/neutron.conf" do
  inifile(:action => :check) do |i|
    i.section "DEFAULT" do
      i.eq "lock_path", "$state_path/lock"
    end
    i.section "keystone_authtoken" do
      i.eq "auth_host", "127.0.0.1"
      i.eq "auth_port", "35357"
    end
  end
  action :nothing
end
