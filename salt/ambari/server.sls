{% set pnda_mirror = pillar['pnda_mirror']['base_url'] %}
{% set misc_packages_path = pillar['pnda_mirror']['misc_packages_path'] %}
{% set mirror_location = pnda_mirror + misc_packages_path %}
{% set jdbc_package = 'je-5.0.73.jar' %}
{%- set cm_host = salt['pnda.ip_addresses']('hadoop_manager')[0] -%}
{% set cmdb_user = pillar['hadoop_manager']['cmdb']['user'] %}
{% set cmdb_database = pillar['hadoop_manager']['cmdb']['database'] %}
{% set cmdb_password = pillar['hadoop_manager']['cmdb']['password'] %}
{%- set cmdb_host = salt['pnda.ip_addresses']('oozie_database')[0] -%}
{% set mysql_root_password = salt['pillar.get']('mysql:root_pw', 'mysqldefault') %}

include:
  - java
  - mysql.connector
  - mysql

ambari-server-user:
  user.present:
    - name: ambari
    - groups:
      - root

ambari-server-init_mysql_user_permissions:
  mysql_user.present:
    - host: {{ cmdb_host }}
    - host: localhost
    - host: '%'
    - name: {{ cmdb_user }}
    - password: {{ cmdb_password }}
    - connection_host: {{ cmdb_host }}
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
  mysql_grants.present:
    - grant: all privileges
    - database: '*.*'
    - user: {{ cmdb_user }}
    - host: {{ cmdb_host }}
    - host: localhost
    - host: '%'
    - connection_host: {{ cmdb_host }}
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
  mysql_database.present:
    - name: {{ cmdb_database }}
    - connection_host: {{ cmdb_host }}
    - connection_user: root
    - connection_pass: {{ mysql_root_password }} 
  cmd.run:
    - name: mysql -h {{ cmdb_host }} -uroot -p{{ mysql_root_password }} {{ cmdb_database }} < /var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql
    - require:
      - pkg: ambari-server-pkg

ambari-server-pkg:
  pkg.installed:
    - name: {{ pillar['ambari-server']['package-name'] }}
    - version: {{ pillar['ambari-server']['version'] }}
    - ignore_epoch: True

ambari-server-properties:
  file.managed:
    - name: /etc/ambari-server/conf/ambari.properties
    - source: salt://ambari/templates/ambari-server.properties.tpl
    - template: jinja
    - mode: 0644
    - defaults:
        java_version_name: {{ pillar['java']['version_name'] }}

ambari-server-log4j:
  file.managed:
    - name: /etc/ambari-server/conf/log4j.properties
    - source: salt://ambari/files/ambari-server-log4j.properties
    - template: jinja
    - mode: 0644

ambari-server-create_log_dir:
  file.directory:
    - name: /var/log/pnda/ambari/
    - makedirs: True

ambari-server-create_jdbc_dir:
  file.directory:
    - name: /opt/pnda/jdbc-driver
    - makedirs: True

ambari-server-jdbc-dl:
  file.managed:
    - name: /opt/pnda/jdbc-driver/{{ jdbc_package }}
    - source: {{ mirror_location }}/{{ jdbc_package }}
    - source_hash: {{ mirror_location }}/{{ jdbc_package }}.sha512.txt

{% if grains['os'] == 'RedHat' %}
ambari-server-systemctl_reload:
  cmd.run:
    - name: /bin/systemctl daemon-reload; /bin/systemctl enable ambari-server
{%- endif %}

ambari-server-setup:
  cmd.run:
    - name: 'ambari-server setup -s -j /usr/share/java/{{ pillar['java']['version_name'] }}/; ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar; ambari-server setup --jdbc-db=bdb --jdbc-driver=/opt/pnda/jdbc-driver/{{ jdbc_package }}'

ambari-server-start_service:
  cmd.run:
    - name: 'service ambari-server stop || echo already stopped; service ambari-server start'
