# Cookbook Name:: sensu
# Recipe:: admin
#
# Copyright 2011, Sonian Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "sensu::default"

package "python-software-properties"
package "libxml2-dev"
package "libxslt-dev"
package "sqlite3"
package "libsqlite3-dev"
package "libmysqlclient-dev"

r = gempackage "rake" do
  version "0.9.2.2"
  action :nothing
end

r.runaction(:install)

execute "chown -R sensu-admin:sensu-admin /etc/sv/sensu-admin/" do
  only_if "test -d /etc/sv/sensu-admin/"
end

group "sensu-admin"

user "sensu-admin" do
  comment "Sensu Admin"
  gid "sensu-admin"
end

cookbook_file "/etc/sudoers.d/sensu-admin" do
  mode "0440"
end

application "sensu-admin" do
  path node.sensu.admin.release_path
  owner "sensu-admin"
  group "sensu-admin"
  action :deploy
  environment "RAILS_ENV" => "production"
  environment_name "production"

  repository "https://github.com/sensu/sensu-admin.git"
  revision "master"

  migrate true
  migration_command "sudo -u sensu-admin bundle exec rake db:migrate db:seed >/tmp/migration.log 2>&1"

  rails do
    database do
      adapter "mysql2"
      encoding "utf8"
      host node.sensu.admin.db_host
      database node.sensu.admin.db_database
      username node.sensu.admin.db_user
      password node.sensu.admin.db_password
      options do
        pool 10
      end
    end
    gems ["whenever", "bundler", "json", "rake", "rest-client", "unicorn"]
    bundler true
    precompile_assets true
  end
  unicorn do
    bundler true
  end
  nginx_load_balancer do
    application_port 8080
    application_server_role "sensu_admin"
    server_name "sensu-admin"
    static_files "/assets" => "public/assets"
    port node.sensu.admin.port
    ssl node.sensu.admin.ssl
    ssl_certificate "/etc/nginx/ssl/server-cert.pem"
    ssl_certificate_key "/etc/nginx/ssl/server-key.pem"
  end
end

template "#{release_path}/current/config/config.yml" do
  owner "sensu-admin"
  group "sensu-admin"
  mode "0600"
  variables(:api_server => node.sensu.admin.api_server)
end


execute "chown -R sensu-admin:sensu-admin /etc/sv/sensu-admin/" do
  only_if "test -d /etc/sv/sensu-admin/"
end

file "/etc/nginx/sites-enabled/000-default" do
  action :delete
end

execute "chown -R sensu-admin:sensu-admin /var/www/websites/sensu-admin/current/log/" do
  only_if "test -d #{node.sensu.admin.release_path}/current/log/"
end

execute "whenever --update-crontab" do
  cwd node.sensu.admin.release_path + "/current"
  user "sensu-admin"
end
