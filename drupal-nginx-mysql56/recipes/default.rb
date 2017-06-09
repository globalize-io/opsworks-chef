apt_package 'mysql-server-5.6' do
  action :install
end

apt_package 'nginx-extras' do
  action :install
end

apt_package 'php5-fpm' do
  action :install
end

apt_package 'php5-mysql' do
  action :install
end

template '/etc/mysql/set.password' do
 source 'set.password.erb'
 owner 'root'
 group 'root'
 mode '640'
 notifies :run, 'execute[create-app-db]'
end

execute 'create-app-db' do
  command "echo \"create database #{node['mysql']['database_name']}\" \| mysql -u root"
  action :nothing
  notifies :run, 'execute[app-permissions]'
end

execute 'app-permissions' do
  command "echo \"grant all privileges on app.* to #{node['mysql']['user_name']}@'localhost' identified by '#{node['mysql']['user_password']}'\" \| mysql -u root"
  notifies :run, 'execute[change-root-password]'
  action :nothing
end

execute 'change-root-password' do
  command "mysqladmin -h localhost -u root password '#{node['mysql']['root_password']}'"
  action :nothing
end

drupal_latest = '/tmp/drupal-latest.tar.gz'
installed_file = node['drupal']['path'] + '/index.php'

remote_file '/tmp/drupal-latest.tar.gz' do
  source "https://ftp.drupal.org/files/projects/drupal-#{node['drupal']['version']}.tar.gz"
  mode '0644'
  not_if 'test -f ' + drupal_latest
end

directory node['drupal']['path'] do
  owner 'www-data'
  group 'www-data'
  mode '0755'
  action :create
  recursive true
end

execute 'untar-drupal' do
  cwd node['drupal']['path']
  command 'tar --strip-components 1 -xzf ' + drupal_latest
  not_if 'test -f ' + installed_file
end

directory node['drupal']['path'] do
  owner 'www-data'
  group 'www-data'
  mode '0755'
  action :create
  recursive true
end

template '/etc/nginx/nginx.conf' do
 source 'nginx.conf.erb'
 owner 'root'
 group 'www-data'
 mode '640'
 notifies :run, 'execute[reload-nginx]'
end

template '/etc/nginx/sites-available/drupal.conf' do
 source 'drupal.conf.erb'
 owner 'root'
 group 'www-data'
 mode '640'
 notifies :run, 'execute[reload-nginx]'
end

link '/etc/nginx/sites-enabled/drupal.conf' do
  to '/etc/nginx/sites-available/drupal.conf'
end

file '/etc/nginx/sites-enabled/default' do
  action :delete
  only_if 'test -f /etc/nginx/sites-enabled/default'
  notifies :run, 'execute[reload-nginx]'
end

execute 'reload-nginx' do
  command 'nginx -t && service nginx reload'
  action :nothing
end

execute 'update-permissions' do
  command "chown -R www-data:www-data #{node['drupal']['path']}"
  command "chmod -R g+rw #{node['drupal']['path']}"
  action :nothing
end
