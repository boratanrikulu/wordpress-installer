#!/bin/bash

WP_DATABASE_NAME="wordpress"
WP_USER_NAME="wordpress"
WP_USER_PASSWORD="password"

die() {
	echo "$*" >&2
	exit 444
}

install_wordpress() {
	echo ""
	echo -en ">>Do you want to remove all files under /var/www/html/ ? [y/n] "
	read answer
	echo ""
	case "$answer" in
		"y" ) rm -rf /var/www/html/* ;;
		"Y" ) rm -rf /var/www/html/* ;;
		"n" ) die "Okay. Installation is cancelled." ;;
		"N" ) die "Okay. Installation is cancelled." ;;
		*   ) echo "Please use only Y or N" ;;
	esac
	
	systemctl restart httpd >/dev/null 2>&1
	systemctl restart mariadb >/dev/null 2>&1
	echo "Downloading wordpress files is started. Please wait..."
	wget http://wordpress.org/latest.tar.gz >/dev/null 2>&1 || die "Downloading wordpress files is failed. Please check your connection."
	echo "Downloading wordpress files is completed ✔"
	tar xzvf latest.tar.gz >/dev/null 2>&1
	cp -rfa wordpress/* /var/www/html/ 
	mkdir /var/www/html/wp-content/uploads 
	chown -R apache:apache /var/www/html/* 
	cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php 
	sed -i "s/database_name_here/${WP_DATABASE_NAME}/g" /var/www/html/wp-config.php
	sed -i "s/username_here/${WP_USER_NAME}/g" /var/www/html/wp-config.php
	sed -i "s/password_here/${WP_USER_PASSWORD}/g" /var/www/html/wp-config.php
	echo ""

	echo "Installation is completed."

	setenforce 0 # to disable selinux

	echo "http://`hostname -I`"	
}

add_wordpress_user_on_mysql() {
	if [[ -e /root/.my.cnf ]]; then
		rm /root/.my.cnf
	fi

	touch /root/.my.cnf
	echo "[client]" >> /root/.my.cnf
	echo "user=root" >> /root/.my.cnf
	echo "password=???" >> /root/.my.cnf
	
	echo "Please enter your password to /root/.my.cnf file to create basic wordpress database."
	echo -en ">> Open /root/.my.cnf (push enter) " && read enter
	nano /root/.my.cnf

	echo ""
	mysql -u root -e "CREATE DATABASE ${WP_DATABASE_NAME};" >/dev/null 2>&1 || echo "> wordpress database is already exist."
	mysql -u root -e "CREATE USER ${WP_USER_NAME}@localhost IDENTIFIED BY '${WP_USER_PASSWORD}';" >/dev/null 2>&1 || echo "> wordpress user is already exist."
	mysql -u root -e "GRANT ALL PRIVILEGES ON wordpress.* TO ${WP_USER_NAME}@localhost IDENTIFIED BY '${WP_USER_PASSWORD}';" >/dev/null 2>&1
	mysql -u root -e "FLUSH PRIVILEGES;" >/dev/null 2>&1

	echo ""
	echo "Adding wordpress user is completed ✔"
	echo "Username: ${WP_USER_NAME}"
	echo "Password: ${WP_USER_PASSWORD}"

	install_wordpress
}

start_installation_wordpress() {
	clear
	echo ""
	echo -en ">>Do you want to install wordpress ? [y/n] "
	read answer
	echo ""

	clear

	case "$answer" in
		"y" ) add_wordpress_user_on_mysql ;;
		"Y" ) add_wordpress_user_on_mysql ;;
		"n" ) die "Okay. Installation is cancelled." ;;
		"N" ) die "Okay. Installation is cancelled." ;;
		*   ) echo "Please use only Y or N" ;;
	esac
}

run_mysql_secure_installation() {
	echo ""
	echo -en ">>Do you want to run mysql_secure_installation ? [y/n] "
	read answer
	echo ""

	case "$answer" in
		"y" ) mysql_secure_installation ;;
		"Y" ) mysql_secure_installation ;;
		"n" ) die "Okay. Installation is cancelled." ;;
		"N" ) die "Okay. Installation is cancelled." ;;
		*   ) echo "Please use only Y or N" ;;
	esac
}

start_the_unstarted_services() {
	unstarted_services=("httpd" "mariadb")

	firewall-cmd --zone=public --add-service=http >/dev/null 2>&1
	firewall-cmd --zone=public --permanent --add-service=http >/dev/null 2>&1

	echo "Starting services are started. Please wait..."
	for service_name in ${unstarted_services[@]}; do
		systemctl start $service_name >/dev/null 2>&1 || die "Starting service is failed. Please check your configs."
		systemctl enable $service_name >/dev/null 2>&1
	done
	echo "Starting services are completed ✔"
}

check_services() {
	service_list=("httpd" "mysqld")
	unstarted_services=()

	echo ""
	stat=0
	for service_name in "${service_list[@]}"; do
		spid=$(pgrep -x $service_name)
		if [[ ! -z $spid ]]; then
			echo "$service_name is up ✔"
		else
			stat+=1
			echo "$service_name is down ✖️"
			unstarted_services+=("$service_name")
		fi
	done

	if [[ ! -z "$unstarted_services" ]]; then
		echo ""
		echo -en ">>Do you want to start the unstarted services ? [y/n] "
		read answer
		echo ""

		case "$answer" in
			"y" ) start_the_unstarted_services ;;
			"Y" ) start_the_unstarted_services ;;
			"n" ) die "Okay. Installation is cancelled." ;;
			"N" ) die "Okay. Installation is cancelled." ;;
			*   ) echo "Please use only Y or N" ;;
		esac
	else
		echo ""
		echo "All services are up."
	fi
}

install_the_uninstalled_packages() {
	uninstalled_packages=$*

	echo "Installation is started. Please wait..."
	for package_name in ${uninstalled_packages[@]}; do
		yum install $package_name -y >/dev/null 2>&1 || die "Installation is failed. Please check your connection."
	done
	echo "Installation is completed ✔"
}

check_packages() {
	package_list=("httpd.x86_64" "mariadb-server.x86_64" "php.x86_64" "php-mysql.x86_64" "php-gd.x86_64" "wget.x86_64")
	uninstalled_packages=""

	yum makecache fast >/dev/null 2>&1

	for package_name in "${package_list[@]}"; do
		if [[ ! `yum list installed | grep -w $package_name | wc -l` -eq "0" ]]; then
			echo "$package_name is installed ✔"
		else
			echo "$package_name is not installed ✖️"
			uninstalled_packages+="$package_name "
		fi
	done

	if [[ ! -z "$uninstalled_packages" ]]; then
		echo ""
		echo -en ">>Do you want to install the uninstalled packages ? [y/n] "
		read answer
		echo ""

		case "$answer" in
			"y" ) install_the_uninstalled_packages "${uninstalled_packages[@]}" ;;
			"Y" ) install_the_uninstalled_packages "${uninstalled_packages[@]}" ;;
			"n" ) die "Okay. Installation is cancelled." ;;
			"N" ) die "Okay. Installation is cancelled." ;;
			*   ) echo "Please use only Y or N" ;;
		esac
	else
		echo ""
		echo "All dependencies are installed."
	fi
}

main() {
	cd
	clear
	check_packages
	check_services
	run_mysql_secure_installation
	start_installation_wordpress
}

if [[ $UID == 0 ]]; then
	main # runs if it has root authority
else
	die "You need to be root to use $0"
fi
