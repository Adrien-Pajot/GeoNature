#!/bin/bash

set -e

. install_functions.sh
. install_db_functions.sh


# CONSTANTS
# DO NOT EDIT THIS CONSTANTS UNLESS YOU MAKE A RELEASE
# Définir dans quelle version de UsersHub (release, branche ou tag) prendre le code SQL permettant la création du schéma utilisateurs de la base de données de GeoNature
export USERSHUB_RELEASE=2.1.1
# Définir dans quelle version de TaxHub (release, branche ou tag) prendre le code SQL permettant la création du schéma taxonomie de la base de données de GeoNature
export TAXHUB_RELEASE=1.6.5
# Définir dans quelle version de Habref-api-module (release, branche ou tag) prendre le code SQL permettant la création du schéma ref_habitats de la base de données de GeoNature
export HABREF_API_RELEASE=0.1.2
# Définir dans quelle version du sous-module des nomenclatures (release, branche ou tag) prendre le code SQL permettant la création du schéma 'ref_nomenclatures' de la base de données GeoNature
# NOMENCLATURE_RELEASE=develop
export NOMENCLATURE_RELEASE=1.3.2

# GN_SCRIPT_PATH=$(get_path_to_script)
# GN_CUR_DIR=${PWD##*/}
export GN_CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export GN_PARENT_DIR="$(dirname "$GN_CUR_DIR")"
export GN_SQL_SCRIPTS_DIR="$GN_PARENT_DIR/data"
export GN_LOG_DIR="$GN_PARENT_DIR/var/log/geonature-db"
# INSTALL_SCRIPTS_DIR=${INSTALL_SCRIPTS_DIR:-"$GN_CUR_DIR"}
export GN_MIGRATION_SCRIPTS_DIR="$GN_PARENT_DIR/data/migrations"

export DB_CONFIG_FILE_PATH="$GN_PARENT_DIR/config/settings.ini" # TODO voir on le laisse ici

# On se positionne à la racine du répertoire geonature
cd "$PARENT_DIR";

# Make sure root cannot run our script
# if [ "$(id -u)" != "0" ]; then
#    echo "This script must be run as root" 1>&2
# #    exit 1
#    return
# fi

if [ -f $DB_CONFIG_FILE_PATH ]
then
    get_config $DB_CONFIG_FILE_PATH
    export GN_POSTGRES_HOST=$db_host
    export GN_POSTGRES_PORT=$db_port
    export GN_POSTGRES_USER=$user_pg
    export GN_POSTGRES_PASSWORD=$user_pg_pass
    export GN_POSTGRES_DB=$db_name
    export GN_POSTGRES_LOCALE=$my_local
    export GN_NOMENCLATURE_LANGUAGE=$default_language
    export GN_LOCAL_SRID=$srid_local
    export GN_ADD_USERSHUB_SAMPLE_DATA=${GN_ADD_USERSHUB_SAMPLE_DATA:-"true"}
    export GN_REFGEO_MUNICIPALITY=$install_sig_layers
    export GN_REFGEO_GRID=$install_grid_layer
    export GN_REFGEO_DEM=$install_default_dem
    export GN_REFGEO_VECTORISE_DEM=$vectorise_dem
    export GN_SAMPLE_DATA=$add_sample_data
else
    echo "\n== Please enter the geoNature database configuration ==\n"
    read -p 'Database host [default: 127.0.0.1]: ' GN_POSTGRES_HOST
    export GN_POSTGRES_HOST=${GN_POSTGRES_HOST:-'127.0.0.1'}

    read -p 'Database port: [default: 5432]: ' GN_POSTGRES_PORT
    export GN_POSTGRES_PORT=${GN_POSTGRES_PORT:-'5432'}
    
    until [[ ! "$GN_POSTGRES_DB" == "" ]]; do
        read -p "Database name: " GN_POSTGRES_DB
    done
    export GN_POSTGRES_DB

    until [[ ! "$GN_POSTGRES_USER" == "" ]]; do
        read -p "Database user: " GN_POSTGRES_USER
    done
    export GN_POSTGRES_USER

    while true; do
        password=""
        repeat_password=""
        until [[ "$password" != "" ]]; do
            read -p -s "Database password: " password
        done
        until [[ "$repeat_password" != "" ]]; do
            read -p -s "Repeat database password: " repeat_password
        done
        if [[ "$password" != "$repeat_password" ]]; then
            printf -e "${START_RED}Passwords don't match. Please try again.${END_RED}\n"
        else 
            export GN_POSTGRES_PASSWORD="$password"
            break
        fi
    done

    read -p 'Database locale [default: fr_FR.UTF-8]: ' GN_POSTGRES_LOCALE
    export GN_POSTGRES_LOCALE=${GN_POSTGRES_LOCALE:-'fr_FR.UTF-8'}

    read -p 'Nomenclature language [fr/it/de...? default: fr]: ' GN_NOMENCLATURE_LANGUAGE
    export GN_NOMENCLATURE_LANGUAGE=${GN_NOMENCLATURE_LANGUAGE:-'fr'}

    read -p 'Local SRID [default: 2154]: ' GN_LOCAL_SRID
    export GN_LOCAL_SRID=${GN_LOCAL_SRID:-'2154'}
    
    export GN_ADD_USERSHUB_SAMPLE_DATA=$(prompt_yes_no "Add userhub sample data ? (Recommanded)")
 
    export GN_REFGEO_MUNICIPALITY=$(prompt_yes_no "Do you want to populate the municipality table with French metropolitan municipalities ? (Recommanded)")

    export GN_REFGEO_GRID=$(prompt_yes_no "Do you want to add the INPN grids layer (grids 1*1, 5*5 and 10*10km)? (Recommanded)")

    export GN_REFGEO_DEM=$(prompt_yes_no "Do you want install french DEM layer (MNT 250m) ? (Recommanded)")

    export GN_REFGEO_VECTORISE_DEM=$(prompt_yes_no "Do you want to vectorize DEM layer ? (Recommanded)")

    export GN_SAMPLE_DATA=$(prompt_yes_no "Add GeoNature sample data ? (Recommanded)")

    generate_config
fi

create_role

if database_exists ${GN_POSTGRES_DB}
then
    printf "${START_ORANGE}WARNING : Database exists we don't have to drop it. Choise migrate, drop it manualy or change database name.${NC}\n"
    migr=$(prompt_yes_no "Do you want to apply migration script ?")
    if [ "$migr" = true ];
    then
        #lancement de migrate_db.sh
        . migration/migrate_db_functions.sh
        apply_missing_migrations
        exit 0
    else
        echo "Nothing was doing. Do it yourself !"
    fi
else
    create_database
fi

# Suppression des fichiers : on ne conserve que les fichiers compressés
clean=$(prompt_yes_no "Do you want to clean temporary files ?")
if [ "$migr" = true ];
then
    echo "Cleaning files..."
    #TODO checker les fichiers à supprimer
    rm tmp/geonature/*.sql
    rm tmp/usershub/*.sql
    rm tmp/taxhub/*.txt
    rm tmp/taxhub/*.sql
    rm tmp/taxhub/*.csv
    rm tmp/habref/*.csv
    rm tmp/habref/*.pdf
    rm tmp/habref/*.sql
    rm tmp/nomenclatures/*.sql
fi
