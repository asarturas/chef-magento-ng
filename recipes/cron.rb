#
# Cookbook Name:: magento-ng
# Recipe:: cron
#
# Copyright (C) 2015 Inviqa UK Limited
#
# All rights reserved - Do Not Redistribute
#

%w( apache nginx ).each do |type|
  node[type]['sites'].each do |name, site|
    next unless site['type'] == 'magento'

    include_recipe 'cron::default'

    primary_indicator_check = ''
    if site['clustered']
      primary_indicator_check = "bash -c '[ -f #{site['clustered']['primary_indicator']} ] && "
    end

    magento = ConfigDrivenHelper::Util.immutablemash_to_hash(node['magento'])

    if site['magento']
      magento = ::Chef::Mixin::DeepMerge.hash_only_merge(
        magento,
        ConfigDrivenHelper::Util.immutablemash_to_hash(site['magento']))
    end

    cron_user = if (!site['cron'].nil?) && site['cron']['user']
                  site['cron']['user']
                else
                  case type
                  when 'apache'
                    node['apache']['user']
                  when 'nginx'
                    node['php-fpm']['pools']['www']['user'].nil? ? node['php-fpm']['user'] : node['php-fpm']['pools']['www']['user']
                  end
                end

    if magento['cron_type'] == 'aoe_scheduler'
      template "/etc/cron.d/magento-#{name}" do
        source 'aoe-cron.erb'
        variables(
          :crons => magento['aoe_scheduler'],
          :cron_user => cron_user,
          :primary_indicator_check => primary_indicator_check,
          :site => site
        )
      end
    else
      cron_d "magento-#{name}" do
        command "#{primary_indicator_check}sh #{site['docroot']}/cron.sh"
        minute magento['cron']['minute']
        user cron_user
      end
    end
  end
end
