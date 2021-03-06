VERSION="1.0.1"

## Utility functions

post() { curl -s -XPOST -H "Content-Type: application/json;" -H "X-Cachet-Token: $CACHET_TOKEN" -d "$2" $CACHET_API$1; }
put() { curl -s -XPUT -H "Content-Type: application/json;" -H "X-Cachet-Token: $CACHET_TOKEN" -d "$2" $CACHET_API$1; }
grepid() { egrep -o '"id":[0-9]+'|tr -cd '[0-9]'; }

#posti() { curl -s -XPOST -H "Content-Type: application/json;" -H "X-Cachet-Token: $CACHET_TOKEN" -d @- $CACHET_API$1; }
#puti() { curl -s -XPUT -H "Content-Type: application/json;" -H "X-Cachet-Token: $CACHET_TOKEN" -d @- $CACHET_API$1; }
#grepidi() { jq .data.id; }


## API functions

create_metric() {

    test "$1" == "--help" && {
        echo -e "Usage:\n    $FN name [suffix] [description] default_value"
        echo -e "\nExamples:\n    $FN \"Main Site Response Time\" seconds \"\" 999"
        echo -e "    $FN \"Some-service Uptime\" \"\" \"0: down; 1: up\" 0\n"
        return 0
    }

    NAME="${1:?}"
    SUFFIX="${2-}"
    DESCRIPTION="${3-}"
    DEFAULT=${4:?}

    post /metrics '{"name":"'"$NAME"'","suffix":"'"$SUFFIX"'","description":"'"$DESCRIPTION"'","default_value":'$DEFAULT'}' | grepid
    #jq -nc '{name:env.NAME,suffix:env.SUFFIX,description:env.DESCRIPTION,default_value:env.DEFAULT|tonumber}' | posti /metrics | grepid
}

post_metric() {

    test "$1" == "--help" && {
        echo -e "Usage:\n    $FN id value [timestamp]"
        echo -e "\nExamples:\n    $FN 3 12.422"
        echo -e "    $FN 5 1 1474298088\n"
        return 0
    }

    ID=${1:?}
    VALUE=${2:?}
    TIMESTAMP=${3-}
    test -n "$3" && TIMESTAMP=',"timestamp":'$3

    post /metrics/$ID/points '{"value":'$VALUE$TIMESTAMP'}' >/dev/null
    #jq -nc '{value:env.VALUE|tonumber,timestamp:env.TIMESTAMP|tonumber}|del(..|select(.==""))' | posti /metrics/$ID/points >/dev/null
}

create_component() {

    NAME="${1:?}"
    DESCRIPTION="${2-}"
    STATUS="${3:-4}"
    LINK="${4-}"
    GROUP_ID="${5:-0}"

    post /components '{"name":"'"$NAME"'","status":'$STATUS',"description":"'"$DESCRIPTION"'","link":"'"$LINK"'","group_id":'$GROUP_ID'}' | grepid
    #jq -nc '{name:env.NAME,status:env.STATUS|tonumber,description:env.DESCRIPTION,link:env.LINK,group_id:env.GROUP_ID|tonumber}' | posti /components | grepid
}

update_component() {

    ID=${1:?}
    STATUS=${2:?}

    put /components/$ID '{"status":'$STATUS'}' >/dev/null
    #jq -nc '{status:env.STATUS|tonumber}' | puti /components/$ID >/dev/null
}

create_component_group() {

    NAME="${1:?}"

    post /components/groups '{"name":"'"$NAME"'"}' | grepid
    #jq -nc '{name:env.NAME}' | posti /components/groups | grepid
}

post_component_incident() {

    NAME="${1:?}"
    MESSAGE="${2:?}"
    STATUS=${3:?}
    VISIBLE=${4:-0}
    COMPONENT_ID=${5:?}
    COMPONENT_STATUS=${6:?}
    NOTIFY="${7:-false}"

    post /incidents '{"name":"'"$NAME"'","message":"'"$MESSAGE"'","status":'$STATUS',"visible":'$VISIBLE',"component_id":'$COMPONENT_ID',"component_status":'$COMPONENT_STATUS',"notify":'$NOTIFY'}' | grepid
    #jq -nc '{name:env.NAME,message:env.MESSAGE,status:env.STATUS|tonumber,visible:env.VISIBLE|tonumber,component_id:env.COMPONENT_ID|tonumber,component_status:env.COMPONENT_STATUS|tonumber,notify:(env.NOTIFY=="true")}' | posti /incidents | grepid
}


## Management functions

init() {

    test -d "$1" && {
        for f in $(ls "$1/"*.conf); do
            (init "$1/$(basename $f)")
        done
        exit
    }

    test -f "$1" || { exit 1; }

    source "$1"

    test -z "$METRIC_ID" && test -n "$METRIC_NAME" && {
        echo "Create metric '$METRIC_NAME'..."
        METRIC_ID=$(create_metric "$METRIC_NAME" "$METRIC_SUFFIX" "$METRIC_DESCRIPTION" "$METRIC_DEFAULT_VALUE")
        echo "METRIC_ID=$METRIC_ID"
    }

    test -z "$COMPONENT_GROUP_ID" && test -n "$COMPONENT_GROUP_NAME" && {
        echo "Create group '$COMPONENT_GROUP_NAME'..."
        COMPONENT_GROUP_ID=$(create_component_group "$COMPONENT_GROUP_NAME")
        echo "COMPONENT_GROUP_ID=$COMPONENT_GROUP_ID"
    }

    test -z "$COMPONENT_ID" && test -n "$COMPONENT_NAME" && {
        echo "Create component '$COMPONENT_NAME'..."
        COMPONENT_ID=$(create_component "$COMPONENT_NAME" "$COMPONENT_DESCRIPTION" "" "$COMPONENT_LINK" "$COMPONENT_GROUP_ID")
        echo "COMPONENT_ID=$COMPONENT_ID"
    }

}

config_test() {

    set -x

    test -d "$1" && {
        for f in $(ls "$1/"*.conf); do
            (config_test "$1/$(basename $f)")
        done
        exit
    }

    test -f "$1" || { exit 1; }

    source "$1"

    TEST_OUTPUT="$(eval $TEST)" && {
        eval $ON_SUCCESS
    } || {
        $ON_ERROR
    }

}

cronline() {

    test "$1" == "--help" && {
        echo -e "Usage:\n    $0 cronline INTERVAL [COMMAND]"
        echo -e "\nExamples:\n    $0 cronline 1"
        echo -e "    $0 cronline 60 echo Once per minute."
        echo -e "    $0 cronline 300 echo Every 5 minutes."
        echo -e "    $0 cronline 3600 echo Once per hour."
        echo -e "    $0 cronline 86400 echo Once per day."
        echo -e "    $0 cronline 2419200 echo Once per month."
        echo -e "    $0 cronline 4838400 echo Every other month."
        echo -e "    $0 cronline 29030400 echo Once per year."
        echo
        return 0
    }

    INTERVAL=${1:?}; shift

    ## https://gist.github.com/sebble/3130cbb8e7c81181d8865fcfa33e428b#file-cronlines-sh
    test $INTERVAL -lt 60 && {
        echo "* * * * * $@"
        return 0
    }

    test $INTERVAL -lt 3600 && {
        MINUTES=$(($INTERVAL/60))
        echo "*/$MINUTES * * * * $@"
        return 0
    }

    test $INTERVAL -lt 86400 && {
        HOURS=$(($INTERVAL/3600))
        echo "0 */$HOURS * * * $@"
        return 0
    }

    test $INTERVAL -lt 2419200 && {
        DAYS=$(($INTERVAL/86400))
        echo "0 0 */$DAYS * * $@"
        return 0
    }

    test $INTERVAL -lt 29030400 && {
        MONTHS=$(($INTERVAL/2419200))
        echo "0 0 1 */$MONTHS * $@"
        return 0
    }

    echo "0 0 1 1 * $@"
}

crontab_file() {

    source "$1"
    test -z "$CRON" && test -n "$INTERVAL" && test "$INTERVAL" =~ '^[0-9]+$' && CRON="$(cronline $INTERVAL)"
    : ${CRON:?}
    echo "$CRON TEST_OUTPUT=\$($TEST) && { $ON_SUCCESS; } || { $ON_ERROR; }"

}

crontab() {

    test "$1" == "--help" && {
        echo -e "Usage:\n    $0 crontab CONFIG_PATH [CONFIG_PATH ..]"
        echo -e "\nExamples:\n    $0 crontab config.d/example.conf"
        echo -e "    $0 crontab config.d"
        echo -e "    $0 crontab config.d/*.conf extra,conf"
        echo -e "    $0 crontab config.d | crontab -u cachet-shell-monitor -"
        echo
        return 0
    }

    #echo "## Usage: $0 $@ >> /var/spool/cron/crontabs/root"
    echo "CACHET_TOKEN=$CACHET_TOKEN"
    echo "CACHET_API=$CACHET_API"
    echo "PATH=$PATH:$PWD"

    for p in "$@"; do
        test -d "$p" && {
            for f in $(ls "$p/"*.conf); do
                (crontab_file "$p/$(basename $f)")
            done
            continue
        }
        test -f "$p" && crontab_file "$p" || {
            echo "Error reading file $p." >&2
            exit 1
        }
    done
}

__install() {

    INSTALL_PATH=${1:-/usr/local/bin}
    set -x
    cp $0 "$INSTALL_PATH/cachet" && \
    chmod 755 "$INSTALL_PATH/cachet" && \
    #echo ln -s cachet "$INSTALL_PATH/cachet-init"
    #echo ln -s cachet "$INSTALL_PATH/cachet-crontab"
    #echo ln -s cachet "$INSTALL_PATH/cachet-config-test"
    #echo ln -s cachet "$INSTALL_PATH/cachet-post-metric"
    #echo ln -s cachet "$INSTALL_PATH/cachet-update-component"
    #echo ln -s cachet "$INSTALL_PATH/cachet-post-component-incident"
    #echo ln -s cachet "$INSTALL_PATH/cachet-post-incident"
    #echo mkdir -p /etc/cachet-shell-monitor.d
    #adduser --no-create-home cachet-shell-monitor
    exit 0
    exit 1
}

__help() {

    echo "--------------------------------------------------"
    echo "Cachet Shell Monitoring Scripts - version $VERSION"
    echo "https://github.com/sebble/cachet-shell-monitor"
    echo "--------------------------------------------------"
    echo
    echo "Usage:"
    echo "    $0 --help"
    echo "    $0 --install [path]"
    echo "    $0 <action> --help"
    echo "    $0 <action> [<action_arguments> ..]"
    echo
    echo "Actions:"
    echo "    create-component NAME [DESCRIPTION] [STATUS] [LINK] [GROUP_ID]"
    echo "    create-component-group NAME"
    echo "    create-metric NAME [SUFFIX] [DESCRIPTION] DEFAULT_VALUE"
    echo "    update-component ID STATUS"
    echo "    post-metric ID VALUE [TIMESTAMP]"
    echo "    post-incident NAME MESSAGE STATUS [VISIBLE] [COMPONENT_ID COMPONENT_STATUS] [NOTIFY]"
    echo "    init CONFIG_PATH"
    echo "    cronline INTERVAL [CRON_COMMAND]"
    echo "    crontab CONFIG_PATH [CONFIG_PATH ..]"
    echo
    echo "Example:"
    echo "    sudo $0 --install /usr/local/bin"
    echo "    export CACHET_API=https://status.example.com/api/v1"
    echo "    export CACHET_TOKEN=8sjn12390vg34ma02nd"
    echo "    vi config.d/example.conf"
    echo "    cachet init config.d"
    echo "    cachet crontab config.d | crontab -u cachet-shell-monitor -"
    echo "    cachet update-component 1 2"
    echo "    curl -s https://status.example.com/api/v1/components/1 | jq ."
    echo
}

__version() {
    echo $VERSION
}


## Main

#SHELL_API=$CACHET_API
#SHELL_TOKEN=$CACHET_TOKEN
#test -f ~/.cachet-shell-monitor && source ~/.cachet-shell-monitor
#CACHET_API=${SHELL_API:-CACHET_API}
#CACHET_TOKEN=${SHELL_TOKEN:-CACHET_TOKEN}

basename $0 | egrep -q "^cachet(.sh)?" && {
    FN=$(echo $1|tr - _); shift
} || {
    FN=$(basename $0|cut -d- -f2-|tr - _)
}

type $FN &>/dev/null && $FN "$@" || {
    echo "Error: Unknown action '$FN'" >&2
    __help
    exit 1
}
