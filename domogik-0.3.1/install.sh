#!/bin/bash
#This file is part of B{Domogik} project (U{http://www.domogik.org}).
#
#License
#=======
#
#B{Domogik} is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#B{Domogik} is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with Domogik. If not, see U{http://www.gnu.org/licenses}.
#
#Module purpose
#==============
#
#Help to manage Domogik installation
#
#Implements
#==========
#
#
#@author: Maxence Dunnewind <maxence@dunnewind.net>
#@copyright: (C) 2007-2012 Domogik project
#@license: GPL(v3)
#@organization: Domogik

# Manage options

function display_usage {
    echo "Usage : "
    echo "  Full installation : ./install.sh"
    echo "  Installation on secondary host : ./install.sh --secondary"
    echo "  Use the C xPL hub instead of the python one : ./install.sh --hub_c"
    echo "  Help : ./install.sh -h"
    echo "         ./install.sh --help"
}

MAIN_INSTALL=y
DOMOGIK_XPL_HUB=python
while [ "$1" ] ; do 
    arg=$1
    case $arg in
        --hub_c) 
            DOMOGIK_XPL_HUB="c"
            echo "The C version of the xPL hub will be used instead of the python one."
            ;;
        --secondary) 
            MAIN_INSTALL="n"
            echo "This installation will be done as a secondary host installation : only manager (and plugins) will be launched on this host."
            ;;
        -h) 
            display_usage
            exit 0
            ;;
        --help) 
            display_usage
            exit 0
            ;;
        *) 
            display_usage
            exit 1
            ;;
    esac	
    shift
done


DMG_HOME=

DMG_ETC=/etc/domogik
DMG_CACHE=/var/cache/domogik
DMG_LIB=/var/lib/domogik
DMG_LOCK=/var/lock/domogik

function stop_domogik {
    if [ -f "/etc/init.d/domogik" -o -f "/etc/rc.d/domogik" ];then
        if [ -d "/var/run/domogik" ];then
            [ -f /etc/conf.d/domogik ] && . /etc/conf.d/domogik
            [ -f /etc/default/domogik ] && . /etc/default/domogik
            if [ -f "/etc/domogik/domogik.cfg" ];then
                echo "There is already a Domogik on this system. Try to stop it before installation..."
                /etc/init.d/domogik stop
            fi
        fi
    fi
}

function run_setup_py {
    MODE=$1
    case $MODE in
        develop|install)
            if [ -f "setup.py" ];then
                python ./ez_setup.py
                python ./setup.py $MODE
                if [ "x$?" != "x0" ];then
                    echo "setup.py script exists with a non 0 return value : $?"
                    exit 13
                fi
            else
                echo "Can't find setup.py, did you download the sources correctly? "
                exit 1
            fi
        ;;
        *)
            echo "Only develop and install modes are available"
        ;;
    esac
}

function test_sources {
    FILENAME=$1
    [ -d "$PWD/src" ] ||( echo "Can't find src/ directory, are you running this script from the sources main directory? (with ./$FILENAME" && exit 2 )
    [ -f "src/domogik/examples/config/domogik.cfg" ] ||( echo "Can't find src/domogik/examples/config/domogik.cfg file!" && exit 3 )
    [ -f "src/domogik/examples/default/domogik" ] ||( echo "Can't find src/domogik/examples/default/domogik file!" && exit 4 )
    [ -f "src/domogik/examples/init/domogik" ] ||( echo "Can't find src/domogik/examples/init/domogik!" && exit 5 )
}

function copy_sample_files {
    read -p "Which user will run domogik, it will be created if it does not exist yet? (default : domogik) " d_user
    d_user=${d_user:-domogik}
    if ! getent passwd $d_user >/dev/null;then
        echo "I can't find informations about this user !"
        read -p "Do you want to create it ? (y/n) " create
        if [ "$create" = "y" ];then
            adduser $d_user
        else
            echo "Please restart this script when the user $d_user will exist."
            exit 9
        fi
    fi
    # For upgrade with 0.1.0
    d_home=$(getent passwd $d_user |cut -d ':' -f 6)

    keep="n"
    already_cfg=
    # create /etc/domogik entry
    if [ ! -d $DMG_ETC ];then
        mkdir $DMG_ETC
        chown $d_user:root $DMG_ETC
        chmod 755 $DMG_ETC
    fi
    # create /var/cache/domogik
    if [ ! -d $DMG_CACHE ];then
        mkdir $DMG_CACHE
        chown $d_user:root $DMG_CACHE
    fi
    # create /var/lib/domogik
    if [ ! -d $DMG_LIB ];then
        mkdir $DMG_LIB
        chown $d_user:root $DMG_LIB
        touch $DMG_LIB/__init__.py
        chown $d_user:root $DMG_LIB/__init__.py
    fi
    # create /var/lock/domogik
    if [ ! -d $DMG_LOCK ];then
        mkdir $DMG_LOCK
        chown $d_user:root $DMG_LOCK
    fi
    # create folders for packages management
    for pkg_rep in pkg-cache cache 
      do
        if [ ! -d $DMG_CACHE/$pkg_rep ];then
            mkdir $DMG_CACHE/$pkg_rep
            chown $d_user:root $DMG_CACHE/$pkg_rep
        fi
    done
    # create folders for packages management
    for pkg_rep in domogik_packages domogik_packages/plugins domogik_packages/externals domogik_packages/stats domogik_packages/url2xpl domogik_packages/design domogik_packages/data
      do
        if [ ! -d $DMG_LIB/$pkg_rep ];then
            mkdir $DMG_LIB/$pkg_rep
            chown $d_user:root $DMG_LIB/$pkg_rep
        fi
    done

    # For upgrade with 0.1
    if [ -f $d_home/.domogik/domogik.cfg ];then
        mv $d_home/.domogik/domogik.cfg $DMG_ETC/domogik.cfg
        chown $d_user:root $DMG_ETC/domogik.cfg
        chmod 640 $DMG_ETC/domogik.cfg
        if [ $MAIN_INSTALL = "y" ] ; then
            cp -f src/domogik/examples/packages/sources.list $DMG_ETC/sources.list
            chown $d_user:root $DMG_ETC/sources.list
            chmod 640 $DMG_ETC/sources.list
        fi
    fi
    if [ ! -f $DMG_ETC/domogik.cfg ];then
        cp -f src/domogik/examples/config/domogik.cfg $DMG_ETC/domogik.cfg
        cp -f src/xplhub/examples/config/xplhub.cfg $DMG_ETC/xplhub.cfg
        chown $d_user:root $DMG_ETC/*.cfg
        chmod 640 $DMG_ETC/*.cfg
        if [ $MAIN_INSTALL = "y" ] ; then
            cp -f src/domogik/examples/packages/sources.list $DMG_ETC/sources.list
            chown $d_user:root $DMG_ETC/sources.list
            chmod 640 $DMG_ETC/sources.list
        fi
    else
        keep="y"
        already_cfg=1
        read -p "You already have Domogik configuration files. Do you want to keep them ? [Y/n]" keep
        if [ "x$keep" = "x" ];then
            keep="y"
        fi
        if [ "$keep" = "n" -o "$keep" = "N" ];then
            cp -f src/domogik/examples/config/domogik.cfg $DMG_ETC/domogik.cfg
            cp -f src/xplhub/examples/config/xplhub.cfg $DMG_ETC/xplhub.cfg
            chown $d_user:root $DMG_ETC/*.cfg
            chmod 640 $DMG_ETC/*.cfg
            if [ $MAIN_INSTALL = "y" ] ; then
                cp -f src/domogik/examples/packages/sources.list $DMG_ETC/sources.list
                chown $d_user:root $DMG_ETC/sources.list
                chmod 640 $DMG_ETC/sources.list
            fi
        fi
    fi
    # Add the xplhub.cfg config file in an existing configuration it it does not exists
    if [ ! -f $DMG_ETC/xplhub.cfg ] ; then
        echo "No existing xplhub.cfg file : creating it"
        cp -f src/xplhub/examples/config/xplhub.cfg $DMG_ETC/xplhub.cfg
        chown $d_user:root $DMG_ETC/xplhub.cfg
        chmod 640 $DMG_ETC/xplhub.cfg
    fi
    if [ -d "/etc/default/" ];then
        if [ "$keep" = "n" -o "$keep" = "N" ];then
            cp src/domogik/examples/default/domogik /etc/default/
        fi
    else
        echo "Can't find the directory where I can copy system-wide config. Usually it is /etc/default/"
        exit 6
    fi
    if [ -d "/etc/logrotate.d/" ];then
        cp src/domogik/examples/logrotate/domogik /etc/logrotate.d/
        cp src/xplhub/examples/logrotate/xplhub /etc/logrotate.d/
        chmod 644 /etc/logrotate.d/domogik
        chmod 644 /etc/logrotate.d/xplhub
    fi
    if [ -d "/etc/init.d/" ];then
        cp src/domogik/examples/init/domogik /etc/init.d/
        chmod +x /etc/init.d/domogik
    elif [ -d "/etc/rc.d/" ];then
        cp src/domogik/examples/init/domogik /etc/rc.d/
        chmod +x /etc/rc.d/domogik
    else
        echo "Init directory does not exist (/etc/init.d or /etc/rc.d)"
        exit 7
    fi
}

function update_default_config {
    if [ ! -f /etc/default/domogik ];then
        echo "Can't find /etc/default/domogik!"
        exit 8
    fi
    [ -f /etc/default/domogik ] &&  sed -i "s;^DOMOGIK_USER.*$;DOMOGIK_USER=$d_user;" /etc/default/domogik
    [ -f /etc/default/domogik ] &&  sed -i "s;^DOMOGIK_XPL_HUB.*$;DOMOGIK_XPL_HUB=${DOMOGIK_XPL_HUB};" /etc/default/domogik

    if [ "$MODE" = "develop" ];then
        arch_path=$(python install/get_arch.py)
        d_custom_path=$PWD/$arch_path
        [ -f /etc/default/domogik ] &&  sed -i "s;^CUSTOM_PATH.*$;CUSTOM_PATH=$d_custom_path;" /etc/default/domogik
    fi
}

function update_default_config_other_hosts {
    if [ ! -f /etc/default/domogik ];then
        echo "Can't find /etc/default/domogik!"
        exit 8
    fi
    [ -f /etc/default/domogik ] &&  sed -i "s;^MANAGER_PARAMS.*$;MANAGER_PARAMS=\"-p\";" /etc/default/domogik
}

function update_user_config {
            
    if [ "$keep" = "n" -o "$keep" = "N" ];then
        if [ "$MODE" = "install" ];then
            prefix=""
            sed -i "s;^package_path.*$;package_path = $DMG_LIB;" $DMG_ETC/domogik.cfg
            sed -i "s;^#src_prefix.*$;#src_prefix = $prefix;" $DMG_ETC/domogik.cfg
        else
            prefix=$PWD/src
            sed -i "s;^package_path.*$;#package_path = $DMG_LIB;" $DMG_ETC/domogik.cfg
            sed -i "s;^#src_prefix.*$;src_prefix = $prefix;" $DMG_ETC/domogik.cfg
        fi

        read -p "Which interface do you want to bind to? (default : lo) : " bind_iface
        bind_iface=${bind_iface:-lo}
        bind_addr=$($CMD_NET $bind_iface|egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"|head -1)
        if [ "x$bind_addr" = "x" ];then
            echo "Can't find the address associated to the interface!"
            exit 20
        fi
        sed -i "s/^bind_interface.*$/bind_interface = $bind_addr/" $DMG_ETC/domogik.cfg
        sed -i "s/^HUB_IFACE.*$/HUB_IFACE=$bind_iface/" /etc/default/domogik
        # will be overide on secondary host
        sed -i "s/^rest_server_ip.*$/rest_server_ip = $bind_addr/" $DMG_ETC/domogik.cfg
    fi
}

function update_rest_config_for_secondary_host {
    if [ "$keep" = "n" -o "$keep" = "N" ];then
        read -p "Ip of the main Domogik installation (ip of Rest server) : " rest_server_ip
        read -p "Port of the main Domogik installation (port of Rest server) : " rest_server_port
        sed -i "s/^rest_server_ip.*$/rest_server_ip = $rest_server_ip/" $DMG_ETC/domogik.cfg
        sed -i "s/^rest_server_port.*$/rest_server_port = $rest_server_port/" $DMG_ETC/domogik.cfg
    fi
}


function update_user_config_db {
           
    # if keep == n
    #  => select the db type (mysql or postgresql
    #  => display auth depenting on the DB type
    # db_ok = false
    # if keep === y
    #  => test the connection based on the config
    #  => set db_ok to result
    # while db_ok == false
    #  => request info comman to all dbs
    #  => test the connection based on the config
    #  => set db_ok to result
    # write out to the file
 
    if [ "$keep" = "n" -o "$keep" = "N" ];then
        # request what db to use
        read -p "Db Type (mysql or postgresql) [mysql] :" db_type
        if [ "$db_type" = "" ];then 
	    db_type="mysql"
        fi
        #Display config config
        if [ "$db_type" = "mysql" ];then 
            echo "You need to have a working Mysql server with a domogik user and database."
            echo "You can create it using these commands (as mysql admin user) :"
            echo " > CREATE DATABASE domogik;"
            echo " > GRANT ALL PRIVILEGES ON domogik.* to domogik@127.0.0.1 IDENTIFIED BY 'randompassword';"
        else
            echo "You need to have a working Postgresql server with a domogik user and database."
            echo "You can create it using these commands (as postgresql admin user) :"
            echo " > su - postgres"
            echo " > createdb domogik"
            echo " > createuser --no-createdb --no-adduser --no-createrole -P domogik"
            echo " > exit"
        fi
        read -p "Press Enter to continue the installation when your setup is ok. "
    fi
    db_ok=

    if [ "$keep" = "y" -o "$keep" = "Y" ];then
        db_user=$(grep "^db_user" $DMG_ETC/domogik.cfg|cut -d'=' -f2|tr -d ' ')
        db_type=$(grep "^db_type" $DMG_ETC/domogik.cfg|cut -d'=' -f2|tr -d ' ')
        db_password=$(grep "^db_password" $DMG_ETC/domogik.cfg|cut -d'=' -f2|tr -d ' ')
        db_port=$(grep "^db_port" $DMG_ETC/domogik.cfg|cut -d'=' -f2|tr -d ' ')
        db_name=$(grep "^db_name" $DMG_ETC/domogik.cfg|cut -d'=' -f2|tr -d ' ')
        db_host=$(grep "^db_host" $DMG_ETC/domogik.cfg|cut -d'=' -f2|tr -d ' ')
        if [ "$db_type" = "mysql" ];then
            echo "SELECT 1;"|mysql -h$db_host -P$db_port -u$db_user -p$db_password $db_name > /dev/null
        else
            psql -h $db_host -p $db_port -U $db_user -d $db_name -c "SELECT 1;" > /dev/null
        fi
        if [ $? -ne 0 ];then
            read -p "Something was wrong, can't access to the database, please check your setup and press Enter to retry."
        else
            db_ok=true
        fi
    fi
    while [ ! $db_ok ];do 
        echo "Please set your database parameters."
        read -p "Username : " db_user
        stty -echo echonl
        read -p "Password : " db_password
        stty echo
        if [ "$db_type" = "mysql" ];then
            read -p "Port [3306] : " db_port
            if [ "$db_port" = "" ];then 
                db_port=3306 
            fi
        else
            read -p "Port [5432] : " db_port
            if [ "$db_port" = "" ];then 
                db_port=5432 
            fi
        fi
        read -p "Host [127.0.0.1] :" db_host
        if [ "$db_host" = "" ];then 
            db_host="127.0.0.1"
        fi
        read -p "Database name [domogik]: " db_name
        if [ "$db_name" = "" ];then 
            db_name="domogik"
        fi
        if [ "$db_type" = "mysql" ];then
            echo "SELECT 1;"|mysql -h$db_host -P$db_port -u$db_user -p$db_password $db_name > /dev/null
        else 
            psql -h $db_host -p $db_port -U $db_user -d $db_name -c "SELECT 1;" > /dev/null
        fi
        if [ $? -ne 0 ];then
            read -p "Something was wrong, can't access to the database, please check your setup and press Enter to retry."
        else
            db_ok=true
            echo "Connection test OK"
            sed -i "s;^db_type.*$;db_type = $db_type;" $DMG_ETC/domogik.cfg
            sed -i "s;^db_user.*$;db_user = $db_user;" $DMG_ETC/domogik.cfg
            sed -i "s;^db_password.*$;db_password = $db_password;" $DMG_ETC/domogik.cfg
            sed -i "s;^db_port.*$;db_port = $db_port;" $DMG_ETC/domogik.cfg
            sed -i "s;^db_name.*$;db_name = $db_name;" $DMG_ETC/domogik.cfg
            sed -i "s;^db_host.*$;db_host = $db_host;" $DMG_ETC/domogik.cfg
        fi
    done
}

function call_app_installer {
    echo "** Calling Application Installer"
    /bin/su -c "python ./install/installer.py" $d_user
    if [ $? -ne 0 ];then
        echo "ERROR : An error occured during app_installer execution, read the previous lines for detail."
        exit 1
    fi
}

function check_tools {
    if [ -x "$(which ip)" ];then
        CMD_NET='ip addr show'
    else
	if [  -x "$(which ifconfig)" ];then
		CMD_NET='ifconfig'
	else
		echo "no network command found"
            	exit 21
        fi
    fi
}


function check_python {
    if [ ! -x "$(which python)" ];then
        echo "No python binary found, please install at least python2.6";
        exit 11
    else
        if python -V 2>&1|grep -qs "Python 2.[345]";then
            echo "Bad python version used, please install at least 2.6, and check /usr/bin/python starts the good version."
            exit 12
        fi
    fi
}

function copy_tools {
    [ -d "/usr/sbin" ] && (cp -f src/tools/dmg* /usr/sbin;chmod +x /usr/sbin/dmg*)
}

function modify_hosts {
    [ -f "/etc/hosts" ] || touch /etc/hosts
    if ! grep localhost /etc/hosts|grep -qs 127.0.0.1;then
        sed -i 's/^\(.*localhost.*\)$/#\1/' /etc/hosts
        echo "127.0.0.1 localhost" >> /etc/hosts
    fi
}

function create_log_dir {
    mkdir -p /var/log/domogik
    chown -R $d_user: /var/log/domogik 
    mkdir -p /var/log/xplhub
    chown -R $d_user: /var/log/xplhub 
}

function install_plugins {
    if [ "$MODE" = "develop" ];then
        chmod +x src/tools/packages/insert_data.py 
        for file in src/share/domogik/plugins/*.json;do
            if [[ $file != "src/share/domogik/plugins/*.json" ]] ; then
                echo "** Parse $file"
                su -c "src/tools/packages/insert_data.py $file" $d_user
                echo "** File $file parsed"
            fi
        done
        for file in src/share/domogik/externals/*.json;do
            if [[ $file != "src/share/domogik/externals/*.json" ]] ; then
                echo "** Parse $file"
                su -c "src/tools/packages/insert_data.py $file" $d_user
                echo "** File $file parsed"
            fi
        done
    fi
}

#Main part
if [ $UID -ne 0 ];then
    echo "Please restart this script as root!"
    exit 10
fi
if [ "$(dirname $0)" != "." ];then
    echo "Please run this script from main source directory (as ./install.sh"
    exit 15
fi
if [ "$(pwd | cut -d"/" -f2)" == "root" ];then
    echo "Please use the Domogik package outside of the /root/ folder"
    exit 20
fi

#stop_domogik
check_tools
check_python
test_sources $0
MODE=install
while [ "$MODE" != "develop" -a "$MODE" != "install" ];do
MODE=install
done
read -p "If you want to use a proxy, please set it now. It will only be used during installation. (ex: http://1.2.3.4:8080)" http_proxy
if [ "x$http_proxy" != "x" ];then
    export http_proxy
fi
#this is needed now only because of old bug (#792) and should be useless for new install
if [ "$SUDO_USER" ];then
    trap "[ -d \"$HOME/.python-eggs\" ] && chown -R $SUDO_USER: $HOME/.python-eggs" EXIT
    [ -d "$HOME/.python-eggs" ] && chown -R $SUDO_USER: $HOME/.python-eggs/ 
else
    trap "[ -d \"$HOME/.python-eggs\" ] && chown -R $USER: $HOME/.python-eggs" EXIT
    [ -d "$HOME/.python-eggs" ] && chown -R $USER: $HOME/.python-eggs/ 
fi

run_setup_py $MODE
copy_sample_files
update_default_config
if [ $MAIN_INSTALL = "n" ] ; then
    update_default_config_other_hosts
fi
update_user_config
if [ $MAIN_INSTALL = "y" ] ; then
    update_user_config_db
else
    update_rest_config_for_secondary_host
fi
copy_tools
create_log_dir
if [ $MAIN_INSTALL = "y" ] ; then
    call_app_installer
    install_plugins
fi
modify_hosts   


echo "Everything seems to be good, Domogik should be installed correctly."
echo "I will start the test_config.py script to check it."
read -p "Please press Enter when ready."
chmod +x ./test_config.py && ./test_config.py
if [ "$SUDO_USER" ];then
    [ -d "$HOME/.python-eggs" ] && chown -R $SUDO_USER: $HOME/.python-eggs/ 
else
    [ -d "$HOME/.python-eggs" ] && chown -R $USER: $HOME/.python-eggs/ 
fi
trap - EXIT
